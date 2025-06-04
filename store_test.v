module sessions

import einar_hjortdal.redict as e_redict

// test_implement ensures all stores implement Store interface correctly
fn test_implement() {
	_ := fn () &Store {
		mut jwtso := JsonWebTokenStoreOptions{}
		return new_jwt_store(mut jwtso) or { panic(err) }
	}
	_ := fn () &Store {
		return new_cookie_store(CookieStoreOptions{}) or { panic(err) }
	}
	_ := fn () &Store {
		mut ro := e_redict.Options{}
		mut rso := RedictStoreOptions{}
		return new_redict_store_cookie(mut rso, CookieOptions{}, mut ro) or { panic(err) }
	}
	_ := fn () &Store {
		mut ro := e_redict.Options{}
		mut jwto := JsonWebTokenOptions{}
		mut rso := RedictStoreOptions{}
		return new_redict_store_jwt(mut rso, mut jwto, mut ro) or { panic(err) }
	}
}
