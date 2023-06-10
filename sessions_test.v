module sessions

fn setup() RedisStore {
	store_opts := RedisStoreOptions{}
	mut store := new_redis_store(store_opts) or { panic(err) }
	return store
}

fn test_new_session() {
	store := setup()
	session := new_session(store, 'test')
	println(session)
}
