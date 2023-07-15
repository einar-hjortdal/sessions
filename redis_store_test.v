module sessions

import net.http
import time
import coachonko.redis

fn setup_request() http.Request {
	return http.new_request(http.Method.get, 'coachonko.com/sugma', 'none')
}

fn setup_default_store() !&RedisStore {
	rso := RedisStoreOptions{}
	co := CookieOptions{
		secret: 'test_secret'
	}
	mut ro := redis.Options{}
	return new_redis_store(rso, co, mut ro)!
}

fn setup_fifteen_minute_store() !&RedisStore {
	rso := RedisStoreOptions{}
	co := CookieOptions{
		secret: 'test_secret'
		max_age: 15 * time.minute
	}
	mut ro := redis.Options{}
	return new_redis_store(rso, co, mut ro)!
}

fn test_new_redis_store() {
	store := setup_default_store() or { panic(err) }
	assert store.max_length == 4096
	assert store.key_prefix == 'session_'
	assert store.expire == 30 * time.minute
}

fn test_new() {
	/*
	*
	* Default store
	*
	*/
	mut store := setup_default_store() or { panic(err) }
	mut request := setup_request()
	mut session := store.new(mut request, 'test_session')
	assert session.name == 'test_session'
	assert session.values == ''
	assert session.is_new == true
	assert session.flashes.len == 0
	/*
	*
	* Fifteen-minute store
	*
	*/
	// TODO test non-default settings
}

fn test_save() {
	/*
	*
	* Default store
	*
	*/
	mut store := setup_default_store() or { panic(err) }
	mut request := setup_request()
	mut session := store.new(mut request, 'test_session')
	store.save(mut request.header, mut session) or { panic(err) }
	// When `RedisStore.CookieOptions.max_age <= 0` 2 `Set-Cookie` headers are set:
	// The first one makes the existing cookie expire, the second one sets a new cookie.
	// The default `RedisStore.CookieOptions.max_age` is set to `0`
	set_cookie_headers := request.header.values(http.CommonHeader.set_cookie)
	assert set_cookie_headers.len == 2
	assert set_cookie_headers[0].starts_with('test_session=') == true
	assert set_cookie_headers[1].starts_with('test_session=') == true
	/*
	*
	* Fifteen-minute store
	*
	*/
}

fn test_new_existing() {
	/*
	*
	* Default store
	*
	*/
	mut store := setup_default_store() or { panic(err) }
	mut request := setup_request()
	mut session_one := store.new(mut request, 'test_session')
	store.save(mut request.header, mut session_one) or { panic(err) }
	// Because the default `RedisStore.CookieOptions.max_age` is set to `0`, when `RedisStore.new` is
	// invoked a new session is created.
	mut session_two := store.new(mut request, 'test_session')
	assert session_two.is_new == true
	assert session_one.id != session_two.id
	/*
	*
	* Fifteen-minute store
	*
	*/
}
