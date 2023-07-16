module redis

import coachonko.redis as c_redis

// test_implement ensures all stores implement Store interface correctly
fn test_implement() {
	_ := fn () &Store {
		return new_jwt_store(JsonWebTokenStoreOptions{}) or { panic(err) }
	}
	_ := fn () &Store {
		return new_cookie_store(CookieStoreOptions{}) or { panic(err) }
	}
	_ := fn () &Store {
		mut ro := c_redis.Options{}
		return new_redis_store(RedisStoreOptions{}, CookieOptions{}, mut ro) or { panic(err) }
	}
}
