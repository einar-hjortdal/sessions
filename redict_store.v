module sessions

import crypto.hmac
import crypto.sha256
import encoding.base64
import json
import net.http
import time
import einar_hjortdal.luuid
import einar_hjortdal.redict

// RedictStoreOptions is the struct to provide to new_redict_store_cookie.
pub struct RedictStoreOptions {
pub:
	// max_length limits the size of the value of the session stored in Redict. Defaults to 4096 bytes.
	max_length int
	// key_prefix is the prefix used used in keys when storing data on a Redict server. Defaults to 'session_'.
	key_prefix string
	// refresh_expire when true resets the `EXPIRE` time when a session is loaded with `new`. Defaults
	// to false.
	refresh_expire bool
}

fn (rso RedictStoreOptions) get_max_length() int {
	if rso.max_length == 0 {
		return 4096
	}
	return rso.max_length
}

fn (rso RedictStoreOptions) get_key_prefix() string {
	if rso.key_prefix == '' {
		return 'session_'
	}
	return rso.key_prefix
}

fn (rso RedictStoreOptions) init() RedictStoreOptions {
	return RedictStoreOptions{
		max_length:     rso.get_max_length()
		key_prefix:     rso.get_key_prefix()
		refresh_expire: rso.refresh_expire
	}
}

/*
*
*
* Cookie version
*
*
*/

// RedictStore contains a `redict.Client` which maintains a pool of connections to a Redict server.
pub struct RedictStoreCookie {
	CookieOptions
	RedictStoreOptions
mut:
	client          &redict.Client
	luuid_generator &luuid.Generator
}

// new_redict_store_cookie returns a new `RedictStore` utilizing the provided `RedictStoreOptions`, `CookieOptions`
// and `redict.Options`.
pub fn new_redict_store_cookie(mut rso RedictStoreOptions, co CookieOptions, ro redict.Options) !&RedictStoreCookie {
	return &RedictStoreCookie{
		CookieOptions:      co
		RedictStoreOptions: rso.init()
		client:             redict.new_client(ro)!
		luuid_generator:    luuid.new_generator()
	}
}

/*
*
* Store interface
*
*/

pub fn (mut store RedictStoreCookie) get(mut request http.Request, name string) Session {
	return Session{}
}

pub fn (mut store RedictStoreCookie) new(request http.Request, name string) Session {
	if request_cookie := get_cookie_value(request, name) {
		if session_id := decode_value(request_cookie, store.secret) {
			if session := store.load(session_id) {
				return session
			} else {
				return new_redict_session(name, store.luuid_generator.v1())
			}
		} else {
			return new_redict_session(name, store.luuid_generator.v1())
		}
	} else {
		return new_redict_session(name, store.luuid_generator.v1())
	}
}

// save stores a `Session` in Redict and gives the client a signed cookie containing the session ID.
// It can also be used to delete a session from Redict and from the client: when `Session.to_prune` is
// is set to `true`, then this method deletes the session data from Redict and instructs the client to
// delete the cookie.
pub fn (mut store RedictStoreCookie) save(mut response_header http.Header, mut session Session) ! {
	if store.CookieOptions.max_age <= 0 || session.to_prune {
		store.client.del('${store.key_prefix}${session.id}')!
		new_cookie_opts := cookie_opts_del(store.CookieOptions)
		cookie := new_cookie(session.name, '', new_cookie_opts)!
		set_cookie(mut response_header, cookie)!
	} else {
		store.set(session)!
		cookie := new_cookie(session.name, session.id, store.CookieOptions)!
		set_cookie(mut response_header, cookie)!
	}
}

/*
*
* Internal
*
*/

fn cookie_opts_del(cookie_opts CookieOptions) CookieOptions {
	return CookieOptions{
		domain:    cookie_opts.domain
		http_only: cookie_opts.http_only
		path:      cookie_opts.path
		secret:    cookie_opts.secret
		secure:    cookie_opts.secure
		max_age:   0
	}
}

fn new_redict_session(name string, id string) Session {
	mut session := new_session(name)
	session.id = id
	return session
}

fn (mut store RedictStoreCookie) set(session Session) ! {
	data := json.encode(session)
	if store.max_length != 0 && data.len > store.max_length {
		return error(format_error_message('The value to store is too big'))
	}

	store.client.set('${store.key_prefix}${session.id}', data, store.max_age)!
}

fn (mut store RedictStoreCookie) load(session_id string) !Session {
	get_res := store.client.get('${store.key_prefix}${session_id}')!
	res := get_res.val()
	match res {
		redict.Nil {
			return error(format_error_message('nil'))
		}
		string {
			mut loaded_session := json.decode(Session, *res)! // https://github.com/vlang/v/issues/24054
			if store.refresh_expire {
				store.client.expire('${store.key_prefix}${session_id}', store.max_age)!
			}

			loaded_session.is_new = false
			return loaded_session
		}
		else {
			return error(format_error_message('Unexpected type returned from redict'))
		}
	}
}

/*
*
*
* JWT version
*
*
*/

pub struct RedictStoreJsonWebToken {
	JsonWebTokenOptions
	RedictStoreOptions
mut:
	client          &redict.Client
	luuid_generator &luuid.Generator
}

pub fn new_redict_store_jwt(mut rso RedictStoreOptions, mut jwto JsonWebTokenOptions, ro redict.Options) !&RedictStoreJsonWebToken {
	return &RedictStoreJsonWebToken{
		JsonWebTokenOptions: jwto.init()!
		RedictStoreOptions:  rso.init()
		client:              redict.new_client(ro)!
		luuid_generator:     luuid.new_generator()
	}
}

struct JsonWebTokenRedictPayload {
	JsonWebTokenPayload
	sid string
}

/*
*
* Store interface
*
*/

pub fn (mut store RedictStoreJsonWebToken) get(mut request http.Request, name string) Session {
	return Session{}
}

pub fn (mut store RedictStoreJsonWebToken) new(request http.Request, name string) Session {
	if payload := store.load_token(request.header, name) {
		session := store.load(payload.sid) or {
			return new_redict_session(name, store.luuid_generator.v1())
		}
		return session
	} else {
		return new_redict_session(name, store.luuid_generator.v1())
	}
}

// save stores a `Session` in Redict and gives the client a signed JWT containing the session ID.
// It can also be used to delete a session from Redict: when `Session.to_prune` is set to `true`, then
// this method deletes the session data from Redict.
pub fn (mut store RedictStoreJsonWebToken) save(mut response_header http.Header, mut session Session) ! {
	if session.to_prune {
		store.client.del('${store.key_prefix}${session.id}')!
	} else {
		new_jwt := store.new_token(session.id)
		response_header.add_custom('${store.prefix}${session.name}', new_jwt)!
		store.set(session)!
	}
}

/*
*
* Internal
*
*/

fn (mut store RedictStoreJsonWebToken) load_token(request_header http.Header, name string) !JsonWebTokenRedictPayload {
	session_header := request_header.get_custom('${store.prefix}${name}') or {
		return error(format_error_message('Header is missing'))
	}
	payload := store.decode_token(session_header)!
	return payload
}

fn (store RedictStoreJsonWebToken) decode_token(token string) !JsonWebTokenRedictPayload {
	if token.contains('.') && token.count('.') == 2 {
		split_token := token.split('.')
		signature_mirror := hmac.new(store.secret.bytes(), '${split_token[0]}.${split_token[1]}'.bytes(),
			sha256.sum, sha256.block_size).bytestr().bytes()
		decoded_signature := base64.url_decode(split_token[2])

		if hmac.equal(decoded_signature, signature_mirror) {
			json_payload := base64.url_decode(split_token[1]).bytestr()
			payload := json.decode(JsonWebTokenRedictPayload, json_payload)!
			store.validate_claims(payload.JsonWebTokenPayload)!
			return payload
		} else {
			return error(format_error_message('Token signature not valid'))
		}
	} else {
		return error(format_error_message('Malformed token'))
	}
}

fn (mut store RedictStoreJsonWebToken) new_token(session_id string) string {
	header := base64.url_encode(json.encode(new_header()).bytes())
	payload := base64.url_encode(json.encode(store.new_payload(session_id)).bytes())

	signature := hmac.new(store.secret.bytes(), '${header}.${payload}'.bytes(), sha256.sum,
		sha256.block_size).bytestr()
	encoded_signature := base64.url_encode(signature.bytes())

	return '${header}.${payload}.${encoded_signature}'
}

fn (mut store RedictStoreJsonWebToken) new_payload(session_id string) JsonWebTokenRedictPayload {
	new_payload := store.JsonWebTokenOptions.new_payload('', mut store.luuid_generator)

	return JsonWebTokenRedictPayload{
		JsonWebTokenPayload: new_payload
		sid:                 session_id
	}
}

fn (mut store RedictStoreJsonWebToken) load(session_id string) !Session {
	get_res := store.client.get('${store.key_prefix}${session_id}')!
	res := get_res.val()
	match res {
		redict.Nil {
			return error(format_error_message('nil'))
		}
		string {
			mut loaded_session := json.decode(Session, *res)! // https://github.com/vlang/v/issues/24054
			if store.refresh_expire {
				expire := time.now() - store.JsonWebTokenOptions.get_exp()
				store.client.expire('${store.key_prefix}${session_id}', expire)!
			}

			loaded_session.is_new = false
			return loaded_session
		}
		else {
			return error(format_error_message('Unexpected type returned from redict'))
		}
	}
}

fn (mut store RedictStoreJsonWebToken) set(session Session) ! {
	data := json.encode(session)
	if store.max_length != 0 && data.len > store.max_length {
		return error(format_error_message('The value to store is too big'))
	}

	expire := time.now() - store.JsonWebTokenOptions.get_exp()
	store.client.set('${store.key_prefix}${session.id}', data, expire)!
}
