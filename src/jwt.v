module sessions

import time
import rand
import encoding.base64
import crypto.hmac
import crypto.sha256
import json

pub struct JsonWebTokenOptions {
mut:
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
	// prefix is a string used to construct the name of the custom HTTP header where the JWT is stored.
	// Defaults to 'Coachonko-'.
	prefix string
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

struct JsonWebTokenHeader {
	alg string
	typ string
}

// JsonWebTokenPayload contains RFC7519 claims.
struct JsonWebTokenPayload {
	// iss is the identifier of the issuer of the token.
	iss string
	// sub is the subject of the token.
	sub string
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
}

fn (mut opts JsonWebTokenOptions) init() ! {
	if opts.secret == '' {
		return error('secret must be provided')
	}

	if opts.issuer == '' {
		opts.issuer = 'Coachonko'
	}

	if opts.app_name == '' {
		opts.app_name = 'Coachonko'
	}

	if opts.audience == '' {
		opts.audience = opts.app_name
	}

	if opts.only_from.format_rfc3339() == '0000-00-00T00:00:00.000Z' {
		opts.only_from = time.parse_rfc3339('2023-07-01T00:00:00.000Z') or {
			return error('Failed to set default only_from value')
		}
	}

	if opts.prefix == '' {
		opts.prefix = 'Coachonko-'
	}
	// TODO validate and format prefixes?
}

fn new_header() JsonWebTokenHeader {
	return JsonWebTokenHeader{
		alg: 'HS256'
		typ: 'JWT'
	}
}

fn (opts JsonWebTokenOptions) new_payload(sub string) JsonWebTokenPayload {
	mut new_exp := opts.get_exp()
	mut new_nbf := opts.get_nbf()

	return JsonWebTokenPayload{
		aud: opts.audience
		iss: opts.issuer
		sub: sub
		exp: new_exp.unix_time()
		nbf: new_nbf.unix_time()
		iat: time.now().unix_time()
		jti: 'token_${rand.uuid_v4()}'
	}
}

fn (opts JsonWebTokenOptions) new_token(sub string) string {
	header := base64.url_encode(json.encode(new_header()).bytes())
	payload := base64.url_encode(json.encode(opts.new_payload(sub)).bytes())

	signature := hmac.new(opts.secret.bytes(), '${header}.${payload}'.bytes(), sha256.sum,
		sha256.block_size).bytestr()
	encoded_signature := base64.url_encode(signature.bytes())

	return '${header}.${payload}.${encoded_signature}'
}

fn (opts JsonWebTokenOptions) get_exp() time.Time {
	if opts.valid_end == 0 {
		if opts.valid_until.unix != 0 {
			return opts.valid_until
		} else {
			return time.now().add(12 * time.hour)
		}
	} else {
		return time.now().add(opts.valid_end)
	}
}

fn (opts JsonWebTokenOptions) get_nbf() time.Time {
	if opts.valid_start == 0 {
		if opts.valid_from.unix != 0 {
			return opts.valid_from
		} else {
			return time.now()
		}
	} else {
		return time.now().add(opts.valid_start)
	}
}

// validate_claims returns an error if:
// - the token is not valid yet (nbf)
// - the token has expired (exp)
// - the application is not meant to consume this token (aud)
// - the token was issued after the given cutoff time (iat)
fn (opts JsonWebTokenOptions) validate_claims(payload JsonWebTokenPayload) ! {
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
	if aud != opts.app_name && aud != '' {
		return error('Token not intended to be consumed by this app')
	}
	// Ensure the token was issued after the given date
	iat := payload.iat
	if iat > 0 && iat < opts.only_from.unix_time() {
		return error('Token was issued before ${opts.only_from.format_rfc3339()}')
	}
	// TODO add filter to exclude specific issuers
	// TODO add filter to only allow specific issuers
}
