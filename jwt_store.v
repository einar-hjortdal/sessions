module sessions

import crypto.hmac
import crypto.sha256
import encoding.base64
import net.http
import time
import x.json2 as json

// JsonWebTokenStoreOptions is the struct to provide to new_jwt_store.
pub struct JsonWebTokenStoreOptions {
	// secret is a string used to sign the token.
	secret string
	// name is the name of the session.
	name string
	// app_name is the name of the application that is meant to consume the token. Defaults to Coachonko.
	app_name string
	// valid_start is the time from the moment the token is created to the moment it becomes valid.
	// If not provided, the token is valid immediately after being issued.
	valid_start time.Duration
	// valid_from is the time when the token becomes valid. Overrides valid_start.
	valid_from time.Time
	// valid_end is the time from the moment the token is created to the moment it is no longer valid.
	// If not provided, the token becomes invalid in 12 hours from the moment it is issued.
	valid_end time.Duration
	// valid_until is the time when the token becomes invalid. Overrides valid_end.
	valid_until time.Time
}

pub struct JsonWebTokenStore {
	JsonWebTokenStoreOptions
}

// Claims contains RFC7519 optional claims.
// The comments explain how to obtain these values.
struct Claims {
	// iss is the identifier of the issuer of the token.
	// JsonWebTokenStoreOptions.name
	iss string
	// sub is the unique id of the subject.
	sub string
	// aud is the identifier of the application that will use the token.
	// JsonWebTokenStoreOptions.app_name
	aud string
	// exp is the expiration timestamp of the token.
	// time.now().add(JsonWebTokenStoreOptions.valid_end).unix_time()
	// JsonWebTokenStoreOptions.valid_until.unix_time()
	exp i64
	// nbf is the timestamp from the moment the token is considered valid.
	// time.now().add(JsonWebTokenStoreOptions.valid_start).unix_time()
	// JsonWebTokenStoreOptions.valid_from.unix_time()
	nbf i64
	// iat is the timestamp of when the token was issued.
	// time.now().unix_time()
	iat i64
	// jwi is the unique id of the token
	// Session.id
	jti string
}

// new_jwt_store creates a JsonWebTokenStore with the given options.
pub fn new_jwt_store(opts JsonWebTokenStoreOptions) !JsonWebTokenStore {
	if opts.secret == '' {
		return error('secret must be provided')
	}

	mut name := opts.name
	if name == '' {
		name = 'session_'
	}

	mut app_name := opts.app_name
	if app_name == '' {
		app_name = 'Coachonko'
	}

	mut valid_end := opts.valid_end
	if valid_end == 0 {
		valid_end = 12 * time.hour
	}

	return JsonWebTokenStore{
		JsonWebTokenStoreOptions: JsonWebTokenStoreOptions{
			secret: opts.secret
			name: name
			valid_start: opts.valid_start
			valid_from: opts.valid_from
			valid_end: valid_end
			valid_until: opts.valid_until
		}
	}
}

struct JsonWebTokenHeader {
	alg string
	typ string
}

pub fn (mut store JsonWebTokenStore) get(mut request http.Request, name string) Session {
	return Session{}
}

pub fn (mut store JsonWebTokenStore) new(mut request http.Request, name string) Session {
	mut s := new_session(store.name)

	if token := request.header.get(http.CommonHeader.authorization) {
		if data := store.decode_token(token) {
			s.values = data
			s.id = data['jwi']
		}
	}

	return s
}

pub fn (mut store JsonWebTokenStore) save(mut response_header http.Header, mut session Session) ! {
	new_jwt := store.new_token(mut session)!
	response_header.add(http.CommonHeader.authorization, new_jwt)
}

fn (store JsonWebTokenStore) new_token(mut session Session) !string {
	store.set_claims(mut session)

	header := JsonWebTokenHeader{
		alg: 'HS256'
		typ: 'JWT'
	}

	json_header := json.encode(header)
	json_payload := json.encode(session.values)

	encoded_header := base64.url_encode(json_header.bytes())
	encoded_payload := base64.url_encode(json_payload.bytes())

	signature := hmac.new(store.secret.bytes(), '${encoded_header}.${encoded_payload}'.bytes(),
		sha256.sum, sha256.block_size).bytestr()
	encoded_signature := base64.url_encode(signature.bytes())

	return '${encoded_header}.${encoded_payload}.${encoded_signature}'
}

fn (store JsonWebTokenStore) set_claims(mut session Session) {
	session.values['iss'] = store.name
	session.values['aud'] = store.app_name

	if store.valid_end == 0 {
		if store.valid_until.unix != 0 {
			session.values['exp'] = store.valid_until.unix_time()
		}
		session.values['exp'] = time.now().add(12 * time.hour)
	} else {
		session.values['exp'] = time.now().add(store.valid_end).unix_time()
	}

	if store.valid_start == 0 {
		if store.valid_from.unix != 0 {
			session.values['nbf'] = store.valid_from.unix_time()
		}
		session.values['nbf'] = time.now().unix_time()
	}

	session.values['iat'] = time.now().unix_time()
	session.values['jti'] = session.id
}

// decode_token returns a decoded payload if the token signature and payload are both valid.
fn (store JsonWebTokenStore) decode_token(token string) !map[string]json.Any {
	split_token := token.split('.')

	signature_mirror := hmac.new(store.secret.bytes(), '${split_token[0]}.${split_token[1]}'.bytes(),
		sha256.sum, sha256.block_size).bytestr().bytes()
	decoded_signature := base64.url_decode(split_token[2])

	if hmac.equal(decoded_signature, signature_mirror) {
		json_payload := base64.url_decode(split_token[1]).bytestr()
		payload := json.decode[map[string]json.Any](json_payload)!
		if store.validate_token(payload) {
			return payload
		}
	} else {
		return error('token signature is not valid')
	}
}

fn (store JsonWebTokenStore) validate_token(token map[string]json.Any) bool {
	now := time.now().unix_time()
	// Ensure the token is already valid and has not yet expired
	if token['nbf'] is i64 {
		if token['nfb'] > now {
			return false
		}
	}
	if token['exp'] is i64 {
		if token['exp'] < now {
			return false
		}
	}

	// Ensure this app is the target audience
	if token['aud'] is string {
		if token['aud'] != store.app_name {
			return false
		}
	}
	return true
}
