module sessions

import net.http
import time
import coachonko.redis

// These tests require a KeyDB instance running and reachable on localhost:6379

fn setup_request() http.Request {
	return http.new_request(http.Method.get, 'coachonko.com/sugma', 'none')
}

fn setup_default_cookie_store() !&RedisStoreCookie {
	mut rso := RedisStoreOptions{}
	co := CookieOptions{
		secret: 'test_secret'
	}
	mut ro := redis.Options{}
	return new_redis_store_cookie(mut rso, co, mut ro)!
}

fn setup_fifteen_minute_store() !&RedisStoreCookie {
	mut rso := RedisStoreOptions{}
	co := CookieOptions{
		secret: 'test_secret'
		max_age: 15 * time.minute
	}
	mut ro := redis.Options{}
	return new_redis_store_cookie(mut rso, co, mut ro)!
}

fn test_new_redis_store_cookie() {
	store := setup_default_cookie_store() or { panic(err) }
	assert store.max_length == 4096
	assert store.key_prefix == 'session_'
}

fn test_new() {
	/*
	*
	* Default store
	*
	*/
	mut store := setup_default_cookie_store() or { panic(err) }
	mut request := setup_request()
	mut session := store.new(request, 'test_session')
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
	mut store := setup_default_cookie_store() or { panic(err) }
	mut request := setup_request()
	mut session := store.new(request, 'test_session')
	store.save(mut request.header, mut session) or { panic(err) }
	// The default `CookieOptions.max_age` is set to `0`.
	// Verify session cookie has no Max-Age attribute.
	mut set_cookie_headers := request.header.values(http.CommonHeader.set_cookie)
	assert set_cookie_headers.len == 1
	assert set_cookie_headers[0].starts_with('test_session') == true
	assert set_cookie_headers[0].contains('Max-Age') == false
	// Verify session data
	mut get_res := store.client.get('${store.key_prefix}${session.id}') or { panic(err) }
	assert get_res.err() == 'nil'
	/*
	*
	* Fifteen-minute store
	*
	*/
	store = setup_fifteen_minute_store() or { panic(err) }
	request = setup_request()
	session = store.new(request, 'test_session')
	store.save(mut request.header, mut session) or { panic(err) }
	set_cookie_headers = request.header.values(http.CommonHeader.set_cookie)
	assert set_cookie_headers.len == 1
	assert set_cookie_headers[0].starts_with('test_session') == true
	assert set_cookie_headers[0].contains('Max-Age') == true
	get_res = store.client.get('${store.key_prefix}${session.id}') or { panic(err) }
	assert get_res.val().contains('${session.id}') == true
}

fn test_new_existing() {
	mut store := setup_fifteen_minute_store() or { panic(err) }
	mut request := setup_request()
	mut session_one := store.new(request, 'test_session')
	session_one.values = 'test_value'
	store.save(mut request.header, mut session_one) or { panic(err) }
	// `Store.save` sets a `Set-Cookie` header but `Store.new` uses the `Request.cookies` map.
	set_cookie_header := request.header.get(http.CommonHeader.set_cookie) or {
		assert false // header missing
		return
	}
	cookie_value := set_cookie_header.trim_string_left('test_session=').split(';')
	request.cookies['test_session'] = cookie_value[0]

	mut session_two := store.new(request, 'test_session')
	assert session_two.is_new == false
	assert session_one.id == session_two.id
	assert session_two.values == 'test_value'
}
