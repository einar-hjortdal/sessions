module sessions

import json
import net.http
import rand
import time
import coachonko.redis

// RedisStoreOptions is the struct to provide to new_redis_store.
pub struct RedisStoreOptions {
	// max_length when not provided defaults 4096 bytes.
	max_length int
	// key_prefix when not provided defaults to 'session_'
	key_prefix string
	// refresh_expire when true resets the `EXPIRE` time when a session is loaded with `new`
	refresh_expire bool
}

// RedisStore contains a `redis.Client` which maintains a pool of connections to a Redis server.
pub struct RedisStore {
	CookieOptions
	RedisStoreOptions
	expire time.Duration
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

	// Store session on Redis for 30 minutes if cookie Max-Age is 0
	mut new_expire := co.max_age
	if new_expire == 0 {
		new_expire = 60 * time.second
	}

	new_client := redis.new_client(mut ro)

	return &RedisStore{
		CookieOptions: co
		RedisStoreOptions: RedisStoreOptions{
			max_length: new_max_length
			key_prefix: new_key_prefix
		}
		expire: new_expire
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
	return new_redis_session(name)
}

pub fn (mut store RedisStore) save(mut response_header http.Header, mut session Session) ! {
	if store.max_age <= 0 {
		store.delete(mut response_header, mut session)!
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

	store.client.set(store.key_prefix + session.id, data, store.expire)!
}

fn (mut store RedisStore) delete(mut response_header http.Header, mut session Session) ! {
	// Remove data from Redis
	store.client.del(store.key_prefix + session.id)!

	// Set cookie to expire
	mut cookie_opts := store.CookieOptions
	cookie_opts.max_age = -1
	cookie := new_cookie(session.name, '', cookie_opts)!
	set_cookie(mut response_header, cookie)!

	// Clear session values from memory
	session.values = ''
}

// load returns true if there is session data in Redis.
fn (mut store RedisStore) load(session_id string) !Session {
	get_res := store.client.get(store.key_prefix + session_id)!
	mut loaded_session := json.decode(Session, get_res.val)!
	if store.refresh_expire {
		store.client.expire(store.key_prefix + session_id, store.expire)!
	}

	loaded_session.is_new = false
	return loaded_session
}
