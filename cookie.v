module sessions

import crypto.hmac
import crypto.sha256
import encoding.base64
import net.http
import time

pub struct CookieOptions {
	domain    string
	http_only bool
	path      string
	// secret is a string used to sign the cookie.
	secret string
	secure bool
mut:
	// max_age=0 means no Max-Age attribute specified and the cookie will be deleted after the browser
	// session ends.
	// max_age<0 means delete cookie immediately.
	// max_age>0 means Max-Age attribute present and given in seconds.
	max_age time.Duration
}

// new_cookie returns an http.Cookie with the value signed with `cookie_opts.secret` and Base64URL encoded.
// Usually, in server-side sessions, the value passed to this function is the `Session.id`.
// Cookies may also be used to store more data than just an ID, for example, the entire Session.
fn new_cookie(name string, value string, cookie_opts CookieOptions) !http.Cookie {
	// Calculate and set the `Expires` field based on the `max_age` value for Internet Explorer compatibility.
	mut new_expires := time.Time{}
	if cookie_opts.max_age > 0 {
		new_expires = time.now().add(cookie_opts.max_age)
	} else if cookie_opts.max_age < 0 {
		// Set it to the past to expire now.
		new_expires = time.unix(1)
	}
	encoded_value := base64.url_encode(value.bytes())
	signature := new_signature(encoded_value, cookie_opts.secret)!
	encoded_signature := base64.url_encode(signature.bytes())

	return http.Cookie{
		domain: cookie_opts.domain
		expires: new_expires
		http_only: cookie_opts.http_only
		max_age: int(cookie_opts.max_age.seconds())
		name: name
		path: cookie_opts.path
		secure: cookie_opts.secure
		value: '${encoded_value}$${encoded_signature}'
	}
}

fn new_signature(encoded_session_id string, secret string) !string {
	if secret == '' {
		return error('The secret cannot be an empty string')
	}
	return hmac.new(secret.bytes(), encoded_session_id.bytes(), sha256.sum, sha256.block_size).bytestr()
}

// decode_value decodes the value of a cookie created with `new_cookie`.
// Whatever value is given to new_cookie will be returned by this function.
// This function returns an error if the signature is not valid.
fn decode_value(value string, secret string) !string {
	value_split := value.split('$')

	decoded_signature := base64.url_decode(value_split[1]).bytestr()
	signature_mirror := new_signature(value_split[0], secret)!

	if hmac.equal(decoded_signature.bytes(), signature_mirror.bytes()) {
		return base64.url_decode(value_split[0]).bytestr()
	}
	return error('Signature not valid')
}

fn get_cookie(request http.Request, name string) !string {
	if value := request.cookies[name] {
		return value
	}
	return error('The request does not contain any cookie named ${name}')
}

fn set_cookie(mut response_header http.Header, cookie http.Cookie) ! {
	cookie_raw := cookie.str()
	if cookie_raw == '' {
		return error('Invalid cookie name')
	}
	response_header.add(http.CommonHeader.set_cookie, cookie_raw)
}
