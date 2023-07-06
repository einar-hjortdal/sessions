module sessions

import net.http
import json

fn setup_request() http.Request {
	return http.new_request(http.Method.get, 'coachonko.com/sugma', 'none')
}

fn test_cookie_store() {
	cookie_store_opts := CookieStoreOptions{
		cookie_opts: CookieOptions{
			secret: 'test_secret'
		}
	}
	mut store := new_cookie_store(cookie_store_opts)
	mut request := setup_request()

	mut session := store.new(request, 'test_session')

	session.values = 'test_value'

	store.save(mut request.header, mut session)!

	set_cookie_header := request.header.get(http.CommonHeader.set_cookie)!
	cookie_value := set_cookie_header.trim_string_left('test_session=')
	decoded_value := decode_value(cookie_value, store.cookie_opts.secret) or {
		assert false
		return
	}
	decoded_session := json.decode(Session, decoded_value)!
	assert decoded_session.id == session.id
	assert decoded_session.values == 'test_value'

	request.cookies['test_session'] = cookie_value
	reloaded_session := store.new(request, 'test_session')
	assert reloaded_session.id == session.id
	assert reloaded_session.values == 'test_value'
}
