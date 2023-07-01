module sessions

import time
import net.http

fn test_new_jwt_store() {
	// must return an error when options do not contain a secret.
	opts_no_secret := JsonWebTokenStoreOptions{}
	if _ := new_jwt_store(opts_no_secret) {
		assert false // should not happen
	} else {
		assert err.msg() == 'secret must be provided'
	}
	// should set correct default values
	opts_defaults := JsonWebTokenStoreOptions{
		secret: 'test'
	}
	if store := new_jwt_store(opts_defaults) {
		assert store.secret == 'test'
		assert store.issuer == 'Coachonko'
		assert store.app_name == 'Coachonko'
		assert store.audience == 'Coachonko'
		assert store.valid_start == 0
		assert store.valid_end == 12 * time.hour
	} else {
		assert false // failed to set defaults
	}
	// should respect user-given values
	opts_given := JsonWebTokenStoreOptions{
		secret: 'test_secret'
		issuer: 'test_issuer'
		app_name: 'test_app'
		audience: 'test_audience'
		valid_start: 2 * 24 * time.hour
		valid_end: 5 * 24 * time.hour
	}
	if store := new_jwt_store(opts_given) {
		assert store.secret == 'test_secret'
		assert store.issuer == 'test_issuer'
		assert store.app_name == 'test_app'
		assert store.audience == 'test_audience'
		assert store.valid_start == 2 * 24 * time.hour
		assert store.valid_end == 5 * 24 * time.hour
	} else {
		assert false // failed to accept given options
	}
	// TODO check overriding values
}

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
	// Should handle existing and invalid authorization header
	header.add(http.CommonHeader.authorization, 'Bearer test')
	if mut store := new_jwt_store(opts_defaults) {
		mut session := store.new(mut header, 'test_session')
		assert session.name == 'test_session'
	} else {
		assert false // failed to create session
	}
	// TODO check existing and valid authorization header
}

fn test_save_session() {
	mut opts := JsonWebTokenStoreOptions{
		secret: 'test'
	}
	mut header := http.Header{} // used as both request and response
	// All defaults
	if mut store := new_jwt_store(opts) {
		mut session := store.new(mut header, 'test_session')
		session.values['sub'] = '453636'
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
