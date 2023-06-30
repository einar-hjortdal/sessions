module sessions

import time

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
		assert store.name == 'session_'
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
		name: 'test_name'
		issuer: 'test_issuer'
		app_name: 'test_app'
		audience: 'test_audience'
		valid_start: 2 * 24 * time.hour
		valid_end: 5 * 24 * time.hour
	}
	if store := new_jwt_store(opts_given) {
		assert store.secret == 'test_secret'
		assert store.name == 'test_name'
		assert store.issuer == 'test_issuer'
		assert store.app_name == 'test_app'
		assert store.audience == 'test_audience'
		assert store.valid_start == 2 * 24 * time.hour
		assert store.valid_end == 5 * 24 * time.hour
	} else {
		assert false // failed to accept given options
	}
}