module sessions

import net.http

// Store is an interface for custom session stores.
// new should return a session from the store or create a new one.
// save should persist session to the underlying store implementation.
pub interface Store {
mut:
	new(request http.Request, name string) Session
	save(mut response_header http.Header, session Session) !
}
