module sessions

import net.http

// Store is an interface for custom session stores.
// get should return a session cached in the registry.
// new should return a session from the store or create a new one.
// save should persist session to the underlying store implementation.
//
// See redis_store.v for an example.
pub interface Store {
mut:
	get(mut request http.Request, name string) Session
	new(mut request http.Request, name string) Session
	save(mut response_header http.Header, mut session Session) !
}
