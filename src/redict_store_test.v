module sessions

import net.http
import time
import einar_hjortdal.redict

fn setup_request() http.Request {
	return http.new_request(http.Method.get, 'coachonko.com/sugma', 'none')
}

/*
*
* Cookie version
*
*/

fn setup_default_cookie_store() !&RedictStoreCookie {
	mut rso := RedictStoreOptions{}
	co := CookieOptions{
		secret: 'test_secret'
	}
	mut ro := redict.Options{
		address:  'localhost:6379'
		password: 'aed3261756c78a862013ac9a4f0d31dc1451a25a79653ff3951a2343f33245e8'
	}
	return new_redict_store_cookie(mut rso, co, mut ro)!
}

fn setup_fifteen_minute_store() !&RedictStoreCookie {
	mut rso := RedictStoreOptions{}
	co := CookieOptions{
		secret:  'test_secret'
		max_age: 15 * time.minute
	}
	mut ro := redict.Options{
		address:  'localhost:6379'
		password: 'aed3261756c78a862013ac9a4f0d31dc1451a25a79653ff3951a2343f33245e8'
	}
	return new_redict_store_cookie(mut rso, co, mut ro)!
}

fn test_new_redict_store_cookie() {
	store := setup_default_cookie_store() or { panic(err) }
	assert store.max_length == 4096
	assert store.key_prefix == 'session_'
}

fn test_store_cookie_new() {
	/*
	*
	* Default store
	*
	*/
	mut store := setup_default_cookie_store() or { panic(err) }
	mut request := setup_request()
	mut session := store.new(request, 'test_session')
	assert session.id != ''
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
	// TODO test provide broken header
	// TODO test refresh_expire
}

fn test_store_cookie_save() {
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
	session.values = 'Some data'
	store.save(mut request.header, mut session) or { panic(err) }
	set_cookie_headers = request.header.values(http.CommonHeader.set_cookie)
	assert set_cookie_headers.len == 1
	assert set_cookie_headers[0].starts_with('test_session')
	assert set_cookie_headers[0].contains('Max-Age')
	get_res = store.client.get('${store.key_prefix}${session.id}') or { panic(err) }
	assert get_res.val().contains('${session.id}')
	assert get_res.val().contains('Some data')

	// Test session.to_prune
	session.to_prune = true
	store.save(mut request.header, mut session) or { panic(err) }
	set_cookie_headers = request.header.values(http.CommonHeader.set_cookie)
	get_res = store.client.get('${store.key_prefix}${session.id}') or { panic(err) }
	assert set_cookie_headers.len == 2
	assert !set_cookie_headers[1].contains('expires')
	assert get_res.err() == 'nil'
}

fn test_store_cookie_new_existing() {
	mut store := setup_fifteen_minute_store() or { panic(err) }
	mut request := setup_request()
	mut session_one := store.new(request, 'test_session')
	session_one.values = 'test_value'
	store.save(mut request.header, mut session_one) or { panic(err) }
	// `Store.save` sets a `Set-Cookie` header but `Store.new` uses the `Request.cookie` method.
	set_cookie_header := request.header.get(http.CommonHeader.set_cookie) or {
		assert false // header missing
		return
	}
	cookie_value := set_cookie_header.trim_string_left('test_session=').split(';')
	cookie := http.Cookie{
		name:  'test_session'
		value: cookie_value[0]
	}
	request.add_cookie(cookie)

	mut session_two := store.new(request, 'test_session')
	assert session_two.is_new == false
	assert session_one.id == session_two.id
	assert session_two.values == 'test_value'
}

/*
*
* JWT version
*
*/

fn setup_default_jwt_store() !&RedictStoreJsonWebToken {
	mut rso := RedictStoreOptions{}
	mut jwto := JsonWebTokenOptions{
		secret: 'test_secret'
	}
	mut ro := redict.Options{
		address:  'localhost:6379'
		password: 'aed3261756c78a862013ac9a4f0d31dc1451a25a79653ff3951a2343f33245e8'
	}
	return new_redict_store_jwt(mut rso, mut jwto, mut ro)!
}

fn test_new_redict_store_jwt() {
	store := setup_default_jwt_store() or { panic(err) }
	assert store.max_length == 4096
	assert store.key_prefix == 'session_'
}

fn test_store_jwt_new() {
	mut store := setup_default_jwt_store() or { panic(err) }
	mut request := setup_request()
	mut session := store.new(request, 'test_session')
	assert session.id != ''
	assert session.name == 'test_session'
	assert session.values == ''
	assert session.is_new == true
	assert session.flashes.len == 0
	// TODO test non-default settings
	// TODO test provide broken header
	// TODO test refresh_expire
}

fn test_store_jwt_save() {
	mut store := setup_default_jwt_store() or { panic(err) }
	mut request := setup_request()
	mut session := store.new(request, 'Test-Session')
	session.values = 'Some data'
	store.save(mut request.header, mut session) or { panic(err) }

	// Verify header is set
	mut custom_headers := request.header.custom_values('Einar-Test-Session')
	assert custom_headers.len == 1
	assert custom_headers[0].count('.') == 2

	// Verify data is put on Redict
	mut get_res := store.client.get('${store.key_prefix}${session.id}') or { panic(err) }
	assert get_res.err() != 'nil'
	assert get_res.val().contains('Test-Session')
	assert get_res.val().contains('Some data')

	// Test session.to_prune
	session.to_prune = true
	store.save(mut request.header, mut session) or { panic(err) }
	get_res = store.client.get('${store.key_prefix}${session.id}') or { panic(err) }
	assert get_res.err() == 'nil'
}

fn test_store_jwt_new_existing() {
	mut store := setup_default_jwt_store() or { panic(err) }
	mut request := setup_request()
	mut session_one := store.new(request, 'Test-Session')
	session_one.values = 'Some data'
	store.save(mut request.header, mut session_one) or { panic(err) }

	mut session_two := store.new(request, 'Test-Session')
	assert session_two.id == session_one.id
	assert session_two.values == session_one.values
	assert session_two.is_new == false
	// TODO test multiple sessions
}
