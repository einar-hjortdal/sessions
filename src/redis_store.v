module sessions

import json
import net.http
import rand
import crypto.hmac
import crypto.sha256
import encoding.base64
import coachonko.redis

// RedisStoreOptions is the struct to provide to new_redis_store_cookie.
pub struct RedisStoreOptions {
mut:
	// max_length limits the size of the value of the session stored in Redis. Defaults to 4096 bytes.
	max_length int
	// key_prefix when not provided defaults to 'session_'
	key_prefix string
	// refresh_expire when true resets the `EXPIRE` time when a session is loaded with `new`. Defaults
	// to false.
	refresh_expire bool
}

fn (mut rso RedisStoreOptions) init() {
	if rso.max_length == 0 {
		rso.max_length = 4096
	}

	if rso.key_prefix == '' {
		rso.key_prefix = 'session_'
	}
}

/*
*
*
* Cookie version
*
*
*/

// RedisStore contains a `redis.Client` which maintains a pool of connections to a Redis server.
pub struct RedisStoreCookie {
	CookieOptions
	RedisStoreOptions
mut:
	client redis.Client
}

// new_redis_store_cookie returns a new `RedisStore` utilizing the provided `RedisStoreOptions`, `CookieOptions`
// and `redis.Options`.
pub fn new_redis_store_cookie(mut rso RedisStoreOptions, co CookieOptions, mut ro redis.Options) !&RedisStoreCookie {
	rso.init()

	return &RedisStoreCookie{
		CookieOptions: co
		RedisStoreOptions: rso
		client: redis.new_client(mut ro)
	}
}

/*
*
* Store interface
*
*/

pub fn (mut store RedisStoreCookie) get(mut request http.Request, name string) Session {
	return Session{}
}

pub fn (mut store RedisStoreCookie) new(request http.Request, name string) Session {
	if request_cookie := get_cookie(request, name) {
		if session_id := decode_value(request_cookie, store.secret) {
			if session := store.load(session_id) {
				return session
			} else {
				return new_redis_session(name)
			}
		} else {
			return new_redis_session(name)
		}
	} else {
		return new_redis_session(name)
	}
}

// save stores a `Session` in Redis and gives the client a signed cookie containing the session ID.
// It can also be used to delete a session from Redis and from the client: when `RedisStoreCookie.max_age`
// is set to `0` or less, then this method deletes the session data from Redis and instructs the client
// to delete the cookie.
pub fn (mut store RedisStoreCookie) save(mut response_header http.Header, mut session Session) ! {
	if store.max_age <= 0 {
		store.client.del(store.key_prefix + session.id)!
		cookie := new_cookie(session.name, '', store.CookieOptions)!
		set_cookie(mut response_header, cookie)!
	} else {
		store.set(session)!
		cookie := new_cookie(session.name, session.id, store.CookieOptions)!
		set_cookie(mut response_header, cookie)!
	}
}

/*
*
* Internal
*
*/

fn new_redis_session(name string) Session {
	mut session := new_session(name)
	session.id = rand.uuid_v4()
	return session
}

fn (mut store RedisStoreCookie) set(session Session) ! {
	data := json.encode(session)
	if store.max_length != 0 && data.len > store.max_length {
		return error('The value to store is too big')
	}

	store.client.set(store.key_prefix + session.id, data, store.max_age)!
}

// load returns true if there is session data in Redis.
fn (mut store RedisStoreCookie) load(session_id string) !Session {
	get_res := store.client.get(store.key_prefix + session_id)!
	mut loaded_session := json.decode(Session, get_res.val())!
	if store.refresh_expire {
		store.client.expire(store.key_prefix + session_id, store.max_age)!
	}

	loaded_session.is_new = false
	return loaded_session
}

/*
*
*
* JWT version
*
*
*/

pub struct RedisStoreJsonWebToken {
	JsonWebTokenOptions
	RedisStoreOptions
mut:
	client redis.Client
}

pub fn new_redis_jwt_store(mut rso RedisStoreOptions, mut jwto JsonWebTokenOptions, mut ro redis.Options) !&RedisStoreJsonWebToken {
	rso.init()
	jwto.init()!

	return &RedisStoreJsonWebToken{
		JsonWebTokenOptions: jwto
		RedisStoreOptions: rso
		client: redis.new_client(mut ro)
	}
}

struct JsonWebTokenRedisPayload {
	JsonWebTokenPayload
	sid string
}

/*
*
* Store interface
*
*/

pub fn (mut store RedisStoreJsonWebToken) get(mut request http.Request, name string) Session {
	return Session{}
}

pub fn (mut store RedisStoreJsonWebToken) new(request http.Request, name string) Session {
	if payload := store.load_token(request.header, name) {
		session := store.load_session(payload.sid) or { return new_session(name) }
		return session
	} else {
		return new_session(name)
	}
}

// save stores a `Session` in Redis and gives the client a signed JWT containing the session ID.
pub fn (mut store RedisStoreJsonWebToken) save(mut response_header http.Header, mut session Session) ! {
	return
}

/*
*
* Internal
*
*/

fn (mut store RedisStoreJsonWebToken) load_token(request_header http.Header, name string) !JsonWebTokenRedisPayload {
	session_header := request_header.get_custom('${store.prefix}${name}') or {
		return error('Header is missing')
	}
	payload := store.decode_token(session_header)!
	return payload
}

// TODO DRY with JsonWebTokenStore decode_token
fn (store RedisStoreJsonWebToken) decode_token(token string) !JsonWebTokenRedisPayload {
	if token.contains('.') && token.count('.') == 2 {
		split_token := token.split('.')
		signature_mirror := hmac.new(store.secret.bytes(), '${split_token[0]}.${split_token[1]}'.bytes(),
			sha256.sum, sha256.block_size).bytestr().bytes()
		decoded_signature := base64.url_decode(split_token[2])

		if hmac.equal(decoded_signature, signature_mirror) {
			json_payload := base64.url_decode(split_token[1]).bytestr()
			payload := json.decode(JsonWebTokenRedisPayload, json_payload)!
			store.validate_claims(payload.JsonWebTokenPayload)!
			return payload
		} else {
			return error('Token signature not valid')
		}
	} else {
		return error('Malformed token')
	}
}

fn (mut store RedisStoreJsonWebToken) load_session(key string) !Session {
	get_res := store.client.get(key)!
	if get_res.err() == 'nil' {
		return error('nil')
	} else {
		return json.decode(Session, get_res.val())
	}
}
