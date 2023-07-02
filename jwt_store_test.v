module sessions

import time
import net.http

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
	mut header := http.Header{}
	if mut store := new_jwt_store(opts_defaults) {
		mut session := store.new(mut header, 'test_session')
		assert session.name == 'test_session'
	} else {
		assert false // failed to create session
	}
	//
	// Should handle existing and invalid authorization header
	//
	header.add(http.CommonHeader.authorization, 'Bearer test')
	if mut store := new_jwt_store(opts_defaults) {
		mut session := store.new(mut header, 'test_session')
		assert session.name == 'test_session'
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
	mut header := http.Header{} // used as both request and response
	// All defaults
	if mut store := new_jwt_store(opts) {
		mut session := store.new(mut header, 'test_session')
		store.save(mut header, mut session) or {
			assert false // failed to save session
			return
		}
		auth_header := header.get(http.CommonHeader.authorization) or {
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
	mut header := http.Header{} // used as both request and response
	mut store := new_jwt_store(opts) or {
		assert false // Should not happen, see test_new_jwt_store
		return
	}
	// Create new session, add some data to it and save it to the header
	mut session := store.new(mut header, 'test_session')
	session.values = '453636'
	store.save(mut header, mut session) or {
		assert false // failed to save session
		return
	}
	// Attempt to read the data from the header to a new session
	session = store.new(mut header, 'test_session')
	assert session.values == '453636'

}

// test_new_save_nfb checks if valid_from works
fn test_new_save_nfb() {
	// nbf
	opts := JsonWebTokenStoreOptions{
		secret: 'test'
		valid_from: time.now().add(12 * time.hour)
	}
	mut header := http.Header{}
	mut store := new_jwt_store(opts) or {
		assert false // Should not happen, see test_new_jwt_store
		return
	}
	mut session := store.new(mut header, 'test_session')
	session.values = 'nbf test'
	store.save(mut header, mut session) or {
		assert false // failed to save session
		return
	}
	session = store.new(mut header, 'test_session')
	assert session.values == ''
}

// test_new_save_exp checks if valid_until works
fn test_new_save_exp() {
	opts := JsonWebTokenStoreOptions{
		secret: 'test'
		valid_until: time.now().add(-12 * time.hour)
	}
	mut header := http.Header{}
	mut store := new_jwt_store(opts) or {
		assert false // Should not happen, see test_new_jwt_store
		return
	}
	mut session := store.new(mut header, 'test_session')
	session.values = 'exp test'
	store.save(mut header, mut session) or {
		assert false // failed to save session
		return
	}
	session = store.new(mut header, 'test_session')
	assert session.values == ''
}

// test_new_save_aud checks if audience works
fn test_new_save_aud() {
	opts := JsonWebTokenStoreOptions{
		secret: 'test'
		audience: 'nobody'
	}
	mut header := http.Header{}
	mut store := new_jwt_store(opts) or {
		assert false // Should not happen, see test_new_jwt_store
		return
	}
	mut session := store.new(mut header, 'test_session')
	session.values = 'aud test'
	store.save(mut header, mut session) or {
		assert false // failed to save session
		return
	}
	session = store.new(mut header, 'test_session')
	assert session.values == ''
}

// test_new_save_iat checks whether only_from works
fn test_new_save_iat() {
		opts := JsonWebTokenStoreOptions{
		secret: 'test'
		only_from: time.now().add(12 * time.hour)
	}
	mut header := http.Header{}
	mut store := new_jwt_store(opts) or {
		assert false // Should not happen, see test_new_jwt_store
		return
	}
	mut session := store.new(mut header, 'test_session')
	session.values = 'iat test'
	store.save(mut header, mut session) or {
		assert false // failed to save session
		return
	}
	session = store.new(mut header, 'test_session')
	assert session.values == ''
}

// TODO test multiple sessions