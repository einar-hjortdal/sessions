module redis

import coachonko.redis as c_redis

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
		mut ro := c_redis.Options{}
		mut rso := RedisStoreOptions{}
		return new_redis_store_cookie(mut rso, CookieOptions{}, mut ro) or { panic(err) }
	}
	_ := fn () &Store {
		mut ro := c_redis.Options{}
		mut jwto := JsonWebTokenOptions{}
		mut rso := RedisStoreOptions{}
		return new_redis_jwt_store(mut rso, mut jwto, mut ro) or { panic(err) }
	}
}
