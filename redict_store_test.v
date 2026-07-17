module sessions

import net.http
import time
import os
import einar_hjortdal.redict

const redict_container_name = 'einar_hjortdal-redict-sessions'
const redict_port = '6381'

fn container_clean() {
	result := os.execute('docker stop ${redict_container_name}')
	if result.exit_code != 0 {
		if result.output.contains('No such container') {
			return
		}
		eprintln(result.output)
	}
}

// Remember to `sudo usermod -aG docker $USER`
fn container_start() ! {
	container_clean() // kill container if already running
	result :=
		os.execute('docker run --rm --detach --name=${redict_container_name} --publish=${redict_port}:6379 registry.redict.io/redict')
	if result.exit_code != 0 {
		return error(result.output)
	}
}

fn container_is_ready() {
	mut redict_is_loading := true
	for redict_is_loading {
		ping := os.execute('docker exec ${redict_container_name} redict-cli ping')
		if ping.output.contains('PONG') {
			redict_is_loading = false
		}

		time.sleep(1 * time.second)
	}
	return
}

fn testsuite_begin() ! {
	container_start()!
	container_is_ready()
}

fn testsuite_end() ! {
	container_clean()
}

fn setup_request() http.Request {
	return http.new_request(http.Method.get, 'einar-hjortdal.com/sugma', 'none')
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
	ro := redict.Options{
		url: '@localhost:${redict_port}/0'
	}
	return new_redict_store_cookie(rso, co, ro)!
}

fn setup_fifteen_minute_store() !&RedictStoreCookie {
	rso := RedictStoreOptions{}
	co := CookieOptions{
		secret:  'test_secret'
		max_age: 15 * time.minute
	}
	ro := redict.Options{
		url: '@localhost:${redict_port}/0'
	}
	return new_redict_store_cookie(rso, co, ro)!
}

fn test_new_redict_store_cookie() {
	store := setup_default_cookie_store()!
	assert store.max_length == 4096
	assert store.key_prefix == 'session_'
}

fn test_store_cookie_new() {
	/*
	*
	* Default store
	*
	*/
	mut store := setup_default_cookie_store()!
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
	mut store := setup_default_cookie_store()!
	mut request := setup_request()
	mut session := store.new(request, 'test_session')
	store.save(mut request.header, session)!
	// The default `CookieOptions.max_age` is set to `0`.
	// Verify session cookie has no Max-Age attribute.
	mut set_cookie_headers := request.header.values(http.CommonHeader.set_cookie)
	assert set_cookie_headers.len == 1
	assert set_cookie_headers[0].starts_with('test_session') == true
	assert set_cookie_headers[0].contains('Max-Age') == false
	// Verify session data
	store.client.get('${store.key_prefix}${session.id}').result() or { assert redict.is_nil(err) }
	/*
	*
	* Fifteen-minute store
	*
	*/
	store = setup_fifteen_minute_store()!
	request = setup_request()
	session = store.new(request, 'test_session')
	session.values = 'Some data'
	store.save(mut request.header, session)!
	set_cookie_headers = request.header.values(http.CommonHeader.set_cookie)
	assert set_cookie_headers.len == 1
	assert set_cookie_headers[0].starts_with('test_session')
	assert set_cookie_headers[0].contains('Max-Age')

	key := '${store.key_prefix}${session.id}'
	mut v := store.client.get(key).result()!
	assert v.contains('${session.id}')
	assert v.contains('Some data')

	// Test session.to_prune
	session.to_prune = true
	store.save(mut request.header, session)!
	set_cookie_headers = request.header.values(http.CommonHeader.set_cookie)
	store.client.get(key).result() or { assert redict.is_nil(err) }
	assert set_cookie_headers.len == 2
	assert !set_cookie_headers[1].contains('expires')
}

fn test_store_cookie_new_existing() {
	mut store := setup_fifteen_minute_store()!
	mut request := setup_request()
	mut session_one := store.new(request, 'test_session')
	session_one.values = 'test_value'
	store.save(mut request.header, session_one)!
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
	ro := redict.Options{
		url: '@localhost:${redict_port}/0'
	}
	return new_redict_store_jwt(mut rso, mut jwto, ro)!
}

fn test_new_redict_store_jwt() {
	store := setup_default_jwt_store()!
	assert store.max_length == 4096
	assert store.key_prefix == 'session_'
}

fn test_store_jwt_new() {
	mut store := setup_default_jwt_store()!
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
	mut store := setup_default_jwt_store()!
	mut request := setup_request()
	mut session := store.new(request, 'Test-Session')
	session.values = 'Some data'
	store.save(mut request.header, session)!

	// Verify header is set
	mut custom_headers := request.header.custom_values('Einar-Hjortdal-Test-Session')
	assert custom_headers.len == 1
	assert custom_headers[0].count('.') == 2

	// Verify data is put on Redict
	key := '${store.key_prefix}${session.id}'
	mut v := store.client.get(key).result()!
	assert v.contains('Test-Session')
	assert v.contains('Some data')

	// Test session.to_prune
	session.to_prune = true
	store.save(mut request.header, session)!
	store.client.get(key).result() or { assert redict.is_nil(err) }
}

fn test_store_jwt_new_existing() {
	mut store := setup_default_jwt_store()!
	mut request := setup_request()
	mut session_one := store.new(request, 'Test-Session')
	session_one.values = 'Some data'
	store.save(mut request.header, session_one)!

	mut session_two := store.new(request, 'Test-Session')
	assert session_two.id == session_one.id
	assert session_two.values == session_one.values
	assert session_two.is_new == false
	// TODO test multiple sessions
}
