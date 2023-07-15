module sessions

import json
import net.http
import rand
import coachonko.redis

// RedisStoreOptions is the struct to provide to new_redis_store.
pub struct RedisStoreOptions {
	// max_length limits the size of the value of the session stored in Redis. Defaults to 4096 bytes.
	max_length int
	// key_prefix when not provided defaults to 'session_'
	key_prefix string
	// refresh_expire when true resets the `EXPIRE` time when a session is loaded with `new`. Defaults
	// to false.
	refresh_expire bool
}

// RedisStore contains a `redis.Client` which maintains a pool of connections to a Redis server.
pub struct RedisStore {
	CookieOptions
	RedisStoreOptions
mut:
	client redis.Client
}

// new_redis_store returns a new `RedisStore` utilizing the provided `RedisStoreOptions`, `CookieOptions`
// and `redis.Options`.
pub fn new_redis_store(rso RedisStoreOptions, co CookieOptions, mut ro redis.Options) !&RedisStore {
	mut new_max_length := rso.max_length
	if new_max_length == 0 {
		new_max_length = 4096
	}

	mut new_key_prefix := rso.key_prefix
	if new_key_prefix == '' {
		new_key_prefix = 'session_'
	}

	new_client := redis.new_client(mut ro)

	return &RedisStore{
		CookieOptions: co
		RedisStoreOptions: RedisStoreOptions{
			max_length: new_max_length
			key_prefix: new_key_prefix
		}
		client: new_client
	}
}

/*
*
* Store interface
*
*/

pub fn (store RedisStore) get(mut request http.Request, name string) Session {
	return Session{}
}

pub fn (mut store RedisStore) new(mut request http.Request, name string) Session {
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
// It can also be used to delete a session from Redis and from the client: when `RedisStore.max_age`
// is set to `0` or less, then this method deletes the session data from Redis and instructs the client
// to delete the cookie.
pub fn (mut store RedisStore) save(mut response_header http.Header, mut session Session) ! {
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

fn (mut store RedisStore) set(session Session) ! {
	data := json.encode(session)
	if store.max_length != 0 && data.len > store.max_length {
		return error('The value to store is too big')
	}

	store.client.set(store.key_prefix + session.id, data, store.max_age)!
}

// load returns true if there is session data in Redis.
fn (mut store RedisStore) load(session_id string) !Session {
	get_res := store.client.get(store.key_prefix + session_id)!
	mut loaded_session := json.decode(Session, get_res.val)!
	if store.refresh_expire {
		store.client.expire(store.key_prefix + session_id, store.max_age)!
	}

	loaded_session.is_new = false
	return loaded_session
}
