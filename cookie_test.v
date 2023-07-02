module sessions

import net.http

fn test_new_cookie() {
	opts := CookieOptions{
		secret: 'test'
	}
	test_cookie := new_cookie('test_name', 'test_value', opts) or {
		assert false
		return
	}
	assert test_cookie.name == 'test_name'
	assert test_cookie.value != ''
	// TODO test options
}

fn test_decoding() {
	opts := CookieOptions{
		secret: 'test'
	}
	test_cookie := new_cookie('test_name', 'test_value', opts) or {
		assert false
		return
	}
	decoded_value := decode_value(test_cookie.value, opts.secret) or {
		assert false
		return
	}
	assert decoded_value == 'test_value'
}

fn test_set_cookie() {
	opts := CookieOptions{
		secret: 'test'
	}
	test_cookie := new_cookie('test_name', 'test_value', opts) or {
		assert false
		return
	}
	mut header := http.Header{}
	set_cookie(mut header, test_cookie) or {
		assert false
		return
	}
	is_cookie_set := header.get(http.CommonHeader.set_cookie) or {
		assert false
		return
	}
}

// TODO test get_cookie: need to create a dummy http.Request
