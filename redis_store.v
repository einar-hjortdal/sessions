module sessions

import net.http
import vweb
import rand
import x.json2 as json
import patrickpissurno.redis

pub struct RedisStoreOptions {
	pool_opts      redis.PoolOpts
	cookie_opts    CookieOptions
	max_length     int
	key_prefix     string
	refresh_expire bool
}

pub struct RedisStore {
	cookie_opts    CookieOptions
	max_length     int
	key_prefix     string
	expire         int
	refresh_expire bool
mut:
	pool redis.RedisPool
}

// new_redis_store creates a new RedisStore with the given RedisStoreOptions.
pub fn new_redis_store(rso RedisStoreOptions) !RedisStore {
	mut pool := redis.new_pool(rso.pool_opts) or { return err }
	mut max_length := rso.max_length
	if max_length == 0 {
		max_length = 4096
	}
	mut key_prefix := rso.key_prefix
	if key_prefix == '' {
		key_prefix = 'session_'
	}
	// Store session on Redis for 30 minutes if cookie Max-Age is 0
	mut expire := rso.cookie_opts.max_age
	if expire == 0 {
		expire = 60 * 30
	}
	return RedisStore{
		cookie_opts: rso.cookie_opts
		max_length: max_length
		key_prefix: key_prefix
		expire: expire
		refresh_expire: rso.refresh_expire
		pool: pool
	}
}

// new returns a session for the given name without adding it to the registry.
pub fn (store RedisStore) new(mut request http.Request, name string) Session {
	session := new_session(store, name)
	session.is_new = true

	if request_cookie := get_cookie(request, name) {
		if session_id := decode_value(request_cookie, store.cookie_opts.secret) {
			session.id = session_id
			if data := store.load(session) {
				session.is_new = false
				return session
			}
		}
	}

	session.id = rand.uuid_v4()
	return session
}

// save adds a single session to the response.
pub fn (store RedisStore) save(mut response_header http.Header, session Session) ! {
	if store.cookie_opts.max_age <= 0 {
		store.delete(response_header, session) or { return err }
		set_cookie(response_header, new_cookie(session.name, '', store.cookie_opts)) or {
			return err
		}
	} else {
		store.set_ex(session) or { return err }
		value := encode_value(session.id, store.cookie_opts.secret)
		set_cookie(response_header, new_cookie(session.name, value, store.cookie_opts)) or {
			return err
		}
	}
}

fn (store RedisStore) set_ex(session Session) ! {
	data := json.encode(session) or { return err }
	if store.max_length != 0 && len(data) > store.max_length {
		return error('The value to store is too big')
	}

	mut conn := store.pool.borrow() or { return err }
	conn.setex(store.key_prefix + session.id, store.expire, data)
	store.pool.release(conn)
	return err
}

fn (store RedisStore) delete(mut response_header http.Header, session Session) ! {
	// Remove data from Redis
	mut conn := store.pool.borrow()
	conn.del(store.key_prefix + session.id) or { return err }
	store.pool.release(conn)

	// Set cookie to expire
	mut cookie_opts := store.cookie_opts
	cookie_opts.max_age = -1
	set_cookie(response_header, new_cookie(session.name, '', cookie_opts)) or { return err }

	// Clear session values from memory
	for k in session.values {
		session.values.delete(k)
	}
}

// load returns true if there is session data in Redis.
fn (store RedisStore) load(session Session) !bool {
	mut conn := store.pool.borrow()
	json_data := conn.get(store.key_prefix + session.id) or {
		store.pool.release(conn)
		return false
	}
	if store.refresh_expire == true {
		conn.expire(store.key_prefix + session.id, store.expire) or {
			store.pool.release(conn)
			return err
		}
	}
	store.pool.release(conn)

	// Put decoded data into the session struct
	data := json.decode(json_data)!
	session.values = data
	return true
}

// close disconnects from the Redis pool
pub fn (store RedisStore) close() ! {
	store.pool.disconnect()
}
