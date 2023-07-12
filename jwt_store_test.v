module sessions

import time
import net.http

fn setup_request() http.Request {
	return http.new_request(http.Method.get, 'coachonko.com/sugma', 'none')
}

// test_new_jwt_store checks whether all options are handled as expected.
fn test_new_jwt_store() {
	// must return an error when options do not contain a secret.
	opts_no_secret := JsonWebTokenStoreOptions{}
	if _ := new_jwt_store(opts_no_secret) {
		assert false // should not happen
	} else {
		assert err.msg() == 'secret must be provided'
	}
	//
	// should set correct default values
	//
	opts_defaults := JsonWebTokenStoreOptions{
		secret: 'test'
	}
	if store := new_jwt_store(opts_defaults) {
		assert store.secret == 'test'
		assert store.issuer == 'Coachonko'
		assert store.only_from.format_rfc3339() == '2023-07-01T00:00:00.000Z'
		assert store.app_name == 'Coachonko'
		assert store.audience == 'Coachonko'
		assert store.valid_start == 0
	} else {
		assert false // failed to set defaults
	}
	//
	// should respect user-given values
	//
	opts_given := JsonWebTokenStoreOptions{
		secret: 'test_secret'
		issuer: 'test_issuer'
		only_from: time.parse_rfc3339('2023-07-01T12:00:00.000Z') or { time.now() }
		app_name: 'test_app'
		audience: 'test_audience'
		valid_start: 2 * 24 * time.hour
		valid_end: 5 * 24 * time.hour
	}
	if store := new_jwt_store(opts_given) {
		assert store.secret == 'test_secret'
		assert store.issuer == 'test_issuer'
		assert store.only_from.format_rfc3339() == '2023-07-01T12:00:00.000Z'
		assert store.app_name == 'test_app'
		assert store.audience == 'test_audience'
		assert store.valid_start == 2 * 24 * time.hour
		assert store.valid_end == 5 * 24 * time.hour
	} else {
		assert false // failed to accept given options
	}
	// TODO check overriding values
}

// test_new_session checks whether a session is successfully created.
fn test_new_session() {
	opts_defaults := JsonWebTokenStoreOptions{
		secret: 'test'
	}
	mut request := setup_request()
	if mut store := new_jwt_store(opts_defaults) {
		mut session := store.new(request, 'Test-Session')
		assert session.name == 'Test-Session'
	} else {
		assert false // failed to create session
	}
	//
	// Should handle existing and invalid authorization header
	//
	request.header.add_custom('Coachonko-Test-Session', 'test')!
	if mut store := new_jwt_store(opts_defaults) {
		mut session := store.new(request, 'Test-Session')
		assert session.name == 'Test-Session'
	} else {
		assert false // failed to create session
	}
	// TODO provide valid_start and valid_from, valid_end and valid_until
}

// test_save_session checks whether a session is successfully stored in a header.
fn test_save_session() {
	mut opts := JsonWebTokenStoreOptions{
		secret: 'test'
	}
	request := setup_request()
	mut header := http.Header{} // used as both request and response
	// All defaults
	if mut store := new_jwt_store(opts) {
		mut session := store.new(request, 'Test-Session')
		store.save(mut header, mut session) or {
			assert false // failed to save session
			return
		}
		auth_header := header.get_custom('Coachonko-Test-Session') or {
			assert false // authorization header missing
			return
		}
		assert auth_header != ''
	} else {
		assert false // failed to create session
	}
}

// test_new_save checks whether a session is successfully created, stored in a token and retrieved.
fn test_new_save() {
	// With this test we set a new valid header and attempt to read it into a session.
	opts := JsonWebTokenStoreOptions{
		secret: 'test'
	}
	mut request := setup_request()
	mut store := new_jwt_store(opts) or {
		assert false // Should not happen, see test_new_jwt_store
		return
	}
	// Create new session, add some data to it and save it to the header
	mut session := store.new(request, 'Test-Session')
	session.values = '453636'
	store.save(mut request.header, mut session) or {
		assert false // failed to save session
		return
	}
	// Attempt to read the data from the header to a new session
	session = store.new(request, 'Test-Session')
	assert session.values == '453636'
}

// test_new_save_nfb checks if valid_from works
fn test_new_save_nfb() {
	// nbf
	opts := JsonWebTokenStoreOptions{
		secret: 'test'
		valid_from: time.now().add(12 * time.hour)
	}
	mut request := setup_request()
	mut store := new_jwt_store(opts) or {
		assert false // Should not happen, see test_new_jwt_store
		return
	}
	mut session := store.new(request, 'Test-Session')
	session.values = 'nbf test'
	store.save(mut request.header, mut session) or {
		assert false // failed to save session
		return
	}
	session = store.new(request, 'Test-Session')
	assert session.values == ''
}

// test_new_save_exp checks if valid_until works
fn test_new_save_exp() {
	opts := JsonWebTokenStoreOptions{
		secret: 'test'
		valid_until: time.now().add(-12 * time.hour)
	}
	mut request := setup_request()
	mut store := new_jwt_store(opts) or {
		assert false // Should not happen, see test_new_jwt_store
		return
	}
	mut session := store.new(request, 'Test-Session')
	session.values = 'exp test'
	store.save(mut request.header, mut session) or {
		assert false // failed to save session
		return
	}
	session = store.new(request, 'Test-Session')
	assert session.values == ''
}

// test_new_save_aud checks if audience works
fn test_new_save_aud() {
	opts := JsonWebTokenStoreOptions{
		secret: 'test'
		audience: 'nobody'
	}
	mut request := setup_request()
	mut store := new_jwt_store(opts) or {
		assert false // Should not happen, see test_new_jwt_store
		return
	}
	mut session := store.new(request, 'Test-Session')
	session.values = 'aud test'
	store.save(mut request.header, mut session) or {
		assert false // failed to save session
		return
	}
	session = store.new(request, 'Test-Session')
	assert session.values == ''
}

// test_new_save_iat checks whether only_from works
fn test_new_save_iat() {
	opts := JsonWebTokenStoreOptions{
		secret: 'test'
		only_from: time.now().add(12 * time.hour)
	}
	mut request := setup_request()
	mut store := new_jwt_store(opts) or {
		assert false // Should not happen, see test_new_jwt_store
		return
	}
	mut session := store.new(request, 'Test-Session')
	session.values = 'iat test'
	store.save(mut request.header, mut session) or {
		assert false // failed to save session
		return
	}
	session = store.new(request, 'Test-Session')
	assert session.values == ''
}

fn test_multiple_sessions() {
	opts_defaults := JsonWebTokenStoreOptions{
		secret: 'test'
	}
	mut request := setup_request()
	mut store := new_jwt_store(opts_defaults) or {
		assert false // Should not happen, see test_new_jwt_store
		return
	}
	mut session_one := store.new(request, 'Test-Session-One')
	session_one.values = 'test value number one'
	mut session_two := store.new(request, 'Test-Session-Two')
	session_two.values = 'test value number two'
	store.save(mut request.header, mut session_one) or {
		assert false // failed to save session
		return
	}
	store.save(mut request.header, mut session_two) or {
		assert false // failed to save session
		return
	}
	println(request.header)
	session_one = store.new(request, 'Test-Session-One')
	session_two = store.new(request, 'Test-Session-Two')
	assert session_one.values == 'test value number one'
	assert session_two.values == 'test value number two'
}
