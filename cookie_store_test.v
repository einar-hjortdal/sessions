module sessions

import json
import net.http
import time

const test_session_secret = 'testSessionSecret'

fn setup_request() http.Request {
	return http.new_request(http.Method.get, 'einar-hjortdal.com/sugma', '')
}

fn test_cookie_store() {
	cookie_store_opts := CookieStoreOptions{
		CookieOptions: CookieOptions{
			secret: 'test_secret'
		}
	}
	mut store := new_cookie_store(cookie_store_opts) or { panic(err) }
	mut request := setup_request()

	name := 'test_session'
	mut session := store.new(request, name)
	assert session.is_new == true

	session.values = 'test_value'
	store.save(mut request.header, session)!

	set_cookie_header := request.header.get(http.CommonHeader.set_cookie)!
	cookie_value := set_cookie_header.trim_string_left('${name}=')
	decoded_value := decode_cookie_value(cookie_value, store.secret)!
	decoded_session := json.decode(Session, decoded_value)!
	assert decoded_session.id == session.id
	assert decoded_session.values == 'test_value'

	cookie := http.Cookie{
		name:  name
		value: cookie_value
	}
	request.add_cookie(cookie)
	reloaded_session := store.new(request, name)
	assert reloaded_session.id == session.id
	assert reloaded_session.values == 'test_value'
}

fn test_with_properties() {
	options := CookieStoreOptions{
		CookieOptions: CookieOptions{
			http_only: true
			path:      '/'
			secret:    test_session_secret
			secure:    true
			max_age:   1 * time.minute
		}
	}

	mut store := new_cookie_store(options) or { panic(err) }
	mut request := setup_request()

	name := 'test_session'
	mut session := store.new(request, name)
	assert session.is_new == true

	session.values = 'test_value'
	store.save(mut request.header, session)!

	set_cookie_header := request.header.get(http.CommonHeader.set_cookie)!
	cookie_value := set_cookie_header.trim_string_left('${name}=').split(';')[0]
	decoded_value := decode_cookie_value(cookie_value, store.secret)!
}
