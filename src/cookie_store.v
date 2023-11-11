module sessions

import net.http
import json

// CookieStoreOptions is the struct to provide to new_cookie_store.
pub struct CookieStoreOptions {
	CookieOptions
}

// CookieStore allows to store session data on the client in the form of a cookie.
pub struct CookieStore {
	CookieStoreOptions
}

fn new_cookie_store(opts CookieStoreOptions) !&CookieStore {
	if opts.secret == '' {
		return error('CookieStoreOptions.cookie_opts.secret must be provided')
	}
	return &CookieStore{
		CookieStoreOptions: opts
	}
}

/*
*
* Store interface
*
*/

pub fn (mut store CookieStore) get(mut request http.Request, name string) Session {
	return Session{}
}

pub fn (mut store CookieStore) new(request http.Request, name string) Session {
	if existing_session := get_cookie_value(request, name) {
		if decoded_value := decode_value(existing_session, store.secret) {
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
	cookie := new_cookie(session.name, encoded_session, store.CookieStoreOptions.CookieOptions)!
	set_cookie(mut response_header, cookie)!
}

/*
*
* Internal
*
*/
