module sessions

import crypto.hmac
import crypto.sha256
import einar_hjortdal.luuid
import encoding.base64
import json
import net.http

// JsonWebTokenStoreOptions is the struct to provide to new_jwt_store.
pub struct JsonWebTokenStoreOptions {
	JsonWebTokenOptions
}

// The JsonWebTokenStore allows to store session data on the client in the form of a JWT.
// Each JWT is stored in its own custom HTTP header.
pub struct JsonWebTokenStore {
	JsonWebTokenStoreOptions
}

// JsonWebTokenStorePayload contains RFC7519 claims together with session data.
// Note: the `sub` claim is not used by this store.
// session is the stored Session.
struct JsonWebTokenStorePayload {
	JsonWebTokenPayload
	session Session
}

// new_jwt_store creates a JsonWebTokenStore with the given options.
pub fn new_jwt_store(mut opts JsonWebTokenStoreOptions) !&JsonWebTokenStore {
	opts.JsonWebTokenOptions.init()!

	return &JsonWebTokenStore{
		JsonWebTokenStoreOptions: opts
	}
}

/*
*
* Store interface
*
*/

pub fn (mut store JsonWebTokenStore) get(mut request http.Request, name string) Session {
	return Session{}
}

pub fn (mut store JsonWebTokenStore) new(request http.Request, name string) Session {
	mut session := new_session(name)
	store.load_token(request.header, mut session) or {
		session.id = 'session_${luuid.v2()}'
		return session
	}
	return session
}

// save stores the `Session` in the response `Header`.
// The HTTP header key is built with the `prefix` followed by the `Session.name`.
// Please remember to use HTTP-header friendly strings for both `prefix` and `Session.name`, otherwise
// `Store.save` will return an error.
pub fn (mut store JsonWebTokenStore) save(mut response_header http.Header, mut session Session) ! {
	new_jwt := store.new_token(session)
	response_header.add_custom('${store.prefix}${session.name}', new_jwt)!
}

/*
*
* Internal
*
*/

// load_token parses the token from the header and loads the data into the session.
// It returns an error if the token is missing or if `Session.name` does not match the one in the parsed
// token.
fn (mut store JsonWebTokenStore) load_token(request_header http.Header, mut session Session) ! {
	session_header := request_header.get_custom('${store.prefix}${session.name}') or {
		return error('Header is missing')
	}
	data := store.decode_token(session_header)!
	if data.session.name == session.name {
		session.id = data.session.id
		session.values = data.session.values
		session.is_new = false
		return
	}
	return error('Token does not contain a session named ${session.name}')
}

// decode_token returns a decoded payload if the token signature and payload are both valid.
fn (store JsonWebTokenStore) decode_token(token string) !JsonWebTokenStorePayload {
	if token.contains('.') && token.count('.') == 2 {
		split_token := token.split('.')
		signature_mirror := hmac.new(store.secret.bytes(), '${split_token[0]}.${split_token[1]}'.bytes(),
			sha256.sum, sha256.block_size).bytestr().bytes()
		decoded_signature := base64.url_decode(split_token[2])

		if hmac.equal(decoded_signature, signature_mirror) {
			json_payload := base64.url_decode(split_token[1]).bytestr()
			payload := json.decode(JsonWebTokenStorePayload, json_payload)!
			store.validate_claims(payload.JsonWebTokenPayload)!
			return payload
		} else {
			return error('Token signature not valid')
		}
	} else {
		return error('Malformed token')
	}
}

fn (store JsonWebTokenStore) new_token(session Session) string {
	header := base64.url_encode(json.encode(new_header()).bytes())
	payload := base64.url_encode(json.encode(store.new_payload(session)).bytes())

	signature := hmac.new(store.secret.bytes(), '${header}.${payload}'.bytes(), sha256.sum,
		sha256.block_size).bytestr()
	encoded_signature := base64.url_encode(signature.bytes())

	return '${header}.${payload}.${encoded_signature}'
}

fn (store JsonWebTokenStore) new_payload(session Session) JsonWebTokenStorePayload {
	new_payload := store.JsonWebTokenStoreOptions.JsonWebTokenOptions.new_payload('')

	return JsonWebTokenStorePayload{
		JsonWebTokenPayload: new_payload
		session:             session
	}
}
