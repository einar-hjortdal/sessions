module sessions

import net.http
import rand
import x.json2 as json
import patrickpissurno.redis

// RedisStoreOptions is the struct to provide to new_redis_store.
pub struct RedisStoreOptions {
	// existing_pool when not provided creates a new RedisPool for sessions storage.
	// When set to true, the provided pre-existing RedisPool will be used instead.
	existing_pool bool
	// pool is the pre-existing RedisPool that will be used when existing_pool is set to true.
	pool redis.RedisPool
	// pool_opts are the options used to create a new RedisPool.
	// https://github.com/patrickpissurno/vredis/
	pool_opts   redis.PoolOpts
	cookie_opts CookieOptions
	// max_length when not provided defaults 4096 bytes.
	max_length int
	// key_prefix when not provided defaults to 'session_'
	key_prefix string
	// refresh_expire when true resets the `EXPIRE` time when a session is loaded with `get` or `new`
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
	mut pool := get_pool(rso)!
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

fn get_pool(rso RedisStoreOptions) !redis.RedisPool {
	if rso.existing_pool {
		return rso.pool
	} else {
		return redis.new_pool(rso.pool_opts)!
	}
}

pub fn (store RedisStore) get(mut request http.Request, name string) Session {
	// todo
	return Session{}
}

// new returns a session for the given name without adding it to the registry.
pub fn (mut store RedisStore) new(mut request http.Request, name string) Session {
	mut session := new_session(name)
	session.is_new = true

	if request_cookie := get_cookie(request, name) {
		if session_id := decode_value(request_cookie, store.cookie_opts.secret) {
			session.id = session_id
			if _ := store.load(mut session) {
				session.is_new = false
				return session
			}
		}
	}

	session.id = rand.uuid_v4()
	return session
}

// save adds a single session to the response.
pub fn (mut store RedisStore) save(mut response_header http.Header, mut session Session) ! {
	if store.cookie_opts.max_age <= 0 {
		store.delete(mut response_header, mut session)!
		set_cookie(mut response_header, new_cookie(session.name, '', store.cookie_opts)) or {
			return err
		}
	} else {
		store.set_ex(session)!
		value := encode_value(session.id, store.cookie_opts.secret)
		set_cookie(mut response_header, new_cookie(session.name, value, store.cookie_opts)) or {
			return err
		}
	}
}

fn (mut store RedisStore) set_ex(session Session) ! {
	data := json.encode[map[string]json.Any](session.values)
	if store.max_length != 0 && data.len > store.max_length {
		return error('The value to store is too big')
	}

	mut conn := store.pool.borrow()!
	conn.setex(store.key_prefix + session.id, store.expire, data)
	store.pool.release(conn)!
}

fn (mut store RedisStore) delete(mut response_header http.Header, mut session Session) ! {
	// Remove data from Redis
	mut conn := store.pool.borrow()!
	conn.del(store.key_prefix + session.id)!
	store.pool.release(conn)!

	// Set cookie to expire
	mut cookie_opts := store.cookie_opts
	cookie_opts.max_age = -1
	set_cookie(mut response_header, new_cookie(session.name, '', cookie_opts))!

	// Clear session values from memory
	for k, _ in session.values {
		session.values.delete(k)
	}
}

// load returns true if there is session data in Redis.
fn (mut store RedisStore) load(mut session Session) !bool {
	mut conn := store.pool.borrow()!
	json_data := conn.get(store.key_prefix + session.id) or {
		store.pool.release(conn)!
		return false
	}
	if store.refresh_expire {
		conn.expire(store.key_prefix + session.id, store.expire) or {
			store.pool.release(conn)!
			return err
		}
	}
	store.pool.release(conn)!

	// Put decoded data into the session struct
	session.values = json.decode[map[string]json.Any](json_data)!
	return true
}

// close disconnects from the Redis pool
pub fn (mut store RedisStore) close() {
	store.pool.disconnect()
}
