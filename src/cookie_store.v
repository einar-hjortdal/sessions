module sessions

import net.http
import json

// CookieStoreOptions is the struct to provide to new_cookie_store.
pub struct CookieStoreOptions {
	cookie_opts CookieOptions
}

// CookieStore allows to store session data on the client in the form of a cookie.
pub struct CookieStore {
	CookieStoreOptions
}

fn new_cookie_store(opts CookieStoreOptions) CookieStore {
	return CookieStore{
		CookieStoreOptions: opts
	}
}

/*
*
* Store interface
*
*/

pub fn (mut store CookieStore) get(request http.Request, name string) Session {
	return Session{}
}

pub fn (mut store CookieStore) new(request http.Request, name string) Session {
	if existing_session := get_cookie(request, name) {
		if decoded_value := decode_value(existing_session, store.cookie_opts.secret) {
			session := json.decode(Session, decoded_value) or { return new_session(name) }
			return session
		} else {
			return new_session(name)
		}
	} else {
		return new_session(name)
	}
}

// save puts the session in a `Set-Cookie` header in the response `Header`.
pub fn (mut store CookieStore) save(mut response_header http.Header, mut session Session) ! {
	encoded_session := json.encode(session)
	cookie := new_cookie(session.name, encoded_session, store.cookie_opts)!
	set_cookie(mut response_header, cookie)!
}

/*
*
* Internal
*
*/
