module sessions

import net.http

// use is the middleware function to be registered in the vweb before_request method.
pub fn use(mut request http.Request, store Store, name string) {
	// TODO middleware function relies on http.Request Context which is not implemented yet
}
