module sessions

import crypto.hmac
import crypto.sha256
import encoding.base64
import net.http
import time

pub struct CookieOptions {
	path      string
	domain    string
	secure    bool
	http_only bool
	// secret is a string used to sign the session id stored in the cookie.
	secret string
mut:
	// max_age=0 means no Max-Age attribute specified and the cookie will be deleted after the browser
	// session ends.
	// max_age<0 means delete cookie immediately.
	// max_age>0 means Max-Age attribute present and given in seconds.
	max_age int
}

fn new_cookie_from_cookie_opts(name string, value string, cookie_opts CookieOptions) http.Cookie {
	return http.Cookie{
		name: name
		value: value
		path: cookie_opts.path
		domain: cookie_opts.domain
		max_age: cookie_opts.max_age
		secure: cookie_opts.secure
		http_only: cookie_opts.http_only
	}
}

fn new_cookie(name string, value string, cookie_opts CookieOptions) http.Cookie {
	mut cookie := new_cookie_from_cookie_opts(name, value, cookie_opts)
	// Calculate and set the `Expires` field based on the `max_age` value for Internet Explorer compatibility.
	if cookie_opts.max_age > 0 {
		d := time.Duration(cookie_opts.max_age) * time.second
		cookie.expires = time.now().add(d)
	} else if cookie_opts.max_age < 0 {
		// Set it to the past to expire now.
		cookie.expires = time.unix(1)
	}
	return cookie
}

fn new_signature(session_id string, secret string) string {
	return hmac.new(secret.bytes(), session_id.bytes(), sha256.sum, sha256.block_size).bytestr()
}

fn encode_value(session_id string, secret string) string {
	signature := new_signature(session_id, secret)
	encoded_session_id := base64.url_encode(session_id.bytes())
	encoded_signature := base64.url_encode(signature.bytes())
	return '${encoded_session_id}$${encoded_signature}'
}

fn decode_value(value string, secret string) !string {
	value_split := value.split('$')
	decoded_session_id := base64.url_decode(value_split[0]).bytestr()
	decoded_signature := base64.url_decode(value_split[1]).bytestr()
	signature_mirror := new_signature(decoded_session_id, secret).bytes()
	if hmac.equal(decoded_signature.bytes(), signature_mirror) {
		return decoded_session_id
	}
	return error('Signature not valid')
}

fn get_cookie(request http.Request, name string) !string {
	if value := request.cookies[name] {
		return value
	}
	return error('Cookie not found')
}

fn set_cookie(mut response_header http.Header, cookie http.Cookie) ! {
	cookie_raw := cookie.str()
	if cookie_raw == '' {
		return error('Invalid cookie name')
	}
	response_header.add(http.CommonHeader.set_cookie, cookie_raw)
}
