module sessions

// Store is an interface for custom session stores.
//
// See redis_store.v for an example.
pub interface Store {
	// get should return a session cached in the registry.
	get(request http.Request, name string) Session
	// new should return a session from the store or create a new one.
	new(request http.Request, name string) Session
	// save should persist session to the underlying store implementation.
	save(mut response_header http.Header, session Session) !
}
