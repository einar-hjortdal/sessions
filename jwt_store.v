module sessions

import crypto.hmac
import crypto.sha256
import encoding.base64
import net.http
import rand
import time
import json

// JsonWebTokenStoreOptions is the struct to provide to new_jwt_store.
pub struct JsonWebTokenStoreOptions {
	// app_name is the name of the application that issued the token.
	// This is usually a domain name and it is compared with the RFC7519 `aud` claim.
	// Defaults to Coachonko.
	app_name string
	// audience is the name of the app or the group of apps that are meant to consume the token.
	// Sets RFC7519 `aud` claim.
	// If not provied it will match the app_name.
	audience string
	// issuer is the identifier of the issuer of the token. Sets RFC7519 `iss` claim.
	// This field is useufl to identify which backend or service issued the token.
	// Defaults to Coachonko.
	issuer string
	// only_from is a timestimp before which no token is considered valid. Defaults to July 1st 2023.
	only_from time.Time
	// secret is a string used to sign the token.
	secret string
	// valid_start is the time from the moment the token is created to the moment it becomes valid.
	// If not provided, the token is valid immediately after being issued.
	valid_start time.Duration
	// valid_end is the time from the moment the token is created to the moment it is no longer valid.
	// If not provided, the token becomes invalid in 12 hours from the moment it is issued.
	valid_end time.Duration
	// valid_from is the time when the token becomes valid. Overrides valid_start.
	valid_from time.Time
	// valid_until is the time when the token becomes invalid. Overrides valid_end.
	valid_until time.Time
}

// The JsonWebTokenStore allows to store session data on the client in the form of a JWT.
pub struct JsonWebTokenStore {
	JsonWebTokenStoreOptions //
	// The CookieStore can save multiple sessions on the same response. It does so by setting a different
	// cookie for each session.
	// A response however, cannot hold multiple Authentication headers. Multiple sessions could still
	// be saved in a single header, but it introduces some complexity:
	// Each time a single JWT is loaded, more than one session may also be loaded. These sessions must
	// be preserved.
	// TODO: implement cache and technique to keep cache small. This cache should contain all the sessions
	// that the JWT held.
	// cache map[string]string
}

struct JsonWebTokenHeader {
	alg string
	typ string
}

// JsonWebTokenPayload contains RFC7519 claims together with session data.
// Note: the `sub` claim is not used by this store.
// The comments explain how the values are set by the store.
struct JsonWebTokenPayload {
	// iss is the identifier of the issuer of the token.
	iss string
	// aud is the identifier of the application that will use the token.
	aud string
	// exp is the expiration timestamp of the token.
	exp i64
	// nbf is the timestamp from the moment the token is considered valid.
	nbf i64
	// iat is the timestamp of when the token was issued.
	iat i64
	// jti is the unique id of the token
	jti string
	// sessions is an array of Session.
	sessions []Session
}

// new_jwt_store creates a JsonWebTokenStore with the given options.
pub fn new_jwt_store(opts JsonWebTokenStoreOptions) !JsonWebTokenStore {
	if opts.secret == '' {
		return error('secret must be provided')
	}

	mut new_issuer := opts.issuer
	if new_issuer == '' {
		new_issuer = 'Coachonko'
	}

	mut new_app_name := opts.app_name
	if new_app_name == '' {
		new_app_name = 'Coachonko'
	}

	mut new_audience := opts.audience
	if new_audience == '' {
		new_audience = new_app_name
	}

	mut new_only_from := opts.only_from
	if new_only_from.format_rfc3339() == '0000-00-00T00:00:00.000Z' {
		new_only_from = time.parse_rfc3339('2023-07-01T00:00:00.000Z') or {
			return error('Failed to set default only_from value')
		}
	}

	return JsonWebTokenStore{
		JsonWebTokenStoreOptions: JsonWebTokenStoreOptions{
			app_name: new_app_name
			audience: new_audience
			issuer: new_issuer
			only_from: new_only_from
			secret: opts.secret
			valid_start: opts.valid_start
			valid_end: opts.valid_end
			valid_from: opts.valid_from
			valid_until: opts.valid_until
		}
	}
}

/*
*
* Store interface
*
*/

pub fn (mut store JsonWebTokenStore) get(mut request_header http.Header, name string) Session {
	return Session{}
}

pub fn (mut store JsonWebTokenStore) new(mut request_header http.Header, name string) Session {
	mut session := new_session(name)
	store.load_token(mut request_header, mut session) or {
		session.id = 'session_${rand.uuid_v4()}'
		return session
	}
	return session
}

// save puts `Session.values` in an `Authorization` header in the response `Header`.
// All session data is put in payload.sessions[session.name].
pub fn (mut store JsonWebTokenStore) save(mut response_header http.Header, mut session Session) ! {
	new_jwt := store.new_token(session)!
	auth_header := 'Bearer ${new_jwt}'
	response_header.add(http.CommonHeader.authorization, auth_header)
}

/*
*
* Internal
*
*/

// load_token parses the token from the `Authorization` header and loads the data into the session.
fn (mut store JsonWebTokenStore) load_token(mut request_header http.Header, mut session Session) ! {
	auth_header := request_header.get(http.CommonHeader.authorization) or {
		return error('Authorization header is missing')
	}
	if auth_header.starts_with('Bearer ') {
		token := auth_header.trim_string_left('Bearer ')
		data := store.decode_token(token)!
		for s in data.sessions {
			if s.name == session.name {
				session.id = s.id
				session.values = s.values
				session.is_new = false
				return
			}
		}
		return error('Token does not contain a session named ${session.name}')
	} else {
		return error('Malformed Authorization header')
	}
}

fn (store JsonWebTokenStore) new_token(session Session) !string {
	header := new_header()
	payload := store.new_payload(session)

	json_header := json.encode(header)
	json_payload := json.encode(payload)

	encoded_header := base64.url_encode(json_header.bytes())
	encoded_payload := base64.url_encode(json_payload.bytes())

	signature := hmac.new(store.secret.bytes(), '${encoded_header}.${encoded_payload}'.bytes(),
		sha256.sum, sha256.block_size).bytestr()
	encoded_signature := base64.url_encode(signature.bytes())

	return '${encoded_header}.${encoded_payload}.${encoded_signature}'
}

fn new_header() JsonWebTokenHeader {
	return JsonWebTokenHeader{
		alg: 'HS256'
		typ: 'JWT'
	}
}

fn (store JsonWebTokenStore) new_payload(session Session) JsonWebTokenPayload {
	mut new_exp := time.Time{}
	if store.valid_end == 0 {
		if store.valid_until.unix != 0 {
			new_exp = store.valid_until
		} else {
			new_exp = time.now().add(12 * time.hour)
		}
	} else {
		new_exp = time.now().add(store.valid_end)
	}

	mut new_nbf := time.Time{}
	if store.valid_start == 0 {
		if store.valid_from.unix != 0 {
			new_nbf = store.valid_from
		} else {
			new_nbf = time.now()
		}
	} else {
		new_nbf = time.now().add(store.valid_start)
	}

	mut new_sessions := [session]

	return JsonWebTokenPayload{
		aud: store.audience
		iss: store.issuer
		exp: new_exp.unix_time()
		nbf: new_nbf.unix_time()
		iat: time.now().unix_time()
		jti: 'token_${rand.uuid_v4()}'
		sessions: new_sessions
	}
}

// decode_token returns a decoded payload if the token signature and payload are both valid.
fn (store JsonWebTokenStore) decode_token(token string) !JsonWebTokenPayload {
	if token.contains('.') && token.count('.') == 2 {
		split_token := token.split('.')
		signature_mirror := hmac.new(store.secret.bytes(), '${split_token[0]}.${split_token[1]}'.bytes(),
			sha256.sum, sha256.block_size).bytestr().bytes()
		decoded_signature := base64.url_decode(split_token[2])

		if hmac.equal(decoded_signature, signature_mirror) {
			json_payload := base64.url_decode(split_token[1]).bytestr()
			payload := json.decode(JsonWebTokenPayload, json_payload)!
			store.validate_token(payload)!
			return payload
		} else {
			return error('Token signature not valid')
		}
	} else {
		return error('Malformed token')
	}
}

// validate_token returns an error if:
// - the token is not valid yet (nbf)
// - the token has expired (exp)
// - the application is not meant to consume this token (aud)
// - the token was issued after the given cutoff time (iat)
fn (store JsonWebTokenStore) validate_token(payload JsonWebTokenPayload) ! {
	now := time.now().unix_time()
	// Ensure the token is already valid and has not yet expired
	nbf := payload.nbf
	if nbf > now && nbf != 0 {
		return error('Token not valid yet')
	}
	// Ensure the token is not expired
	exp := payload.exp
	if exp < now && exp != 0 {
		return error('Token has expired')
	}
	// Ensure the app_name is in the audience
	aud := payload.aud
	if aud != store.app_name && aud != '' {
		return error('Token not intended to be consumed by this app')
	}
	// Ensure the token was issued after the given date
	iat := payload.iat
	if iat > 0 && iat < store.only_from.unix_time() {
		return error('Token was issued before ${store.only_from.format_rfc3339()}')
	}
	// TODO add filter to exclude specific issuers
	// TODO add filter to only allow specific issuers
}
