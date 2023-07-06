module sessions

import net.http

fn setup_request() http.Request {
	return http.new_request(http.Method.get, 'coachonko.com/sugma', 'none')
}

fn setup_basic_cookie_opts() CookieOptions {
	return CookieOptions{
		secret: 'test'
	}
}

fn test_new_cookie() {
	opts := setup_basic_cookie_opts()
	test_cookie := new_cookie('test_name', 'test_value', opts) or {
		assert false
		return
	}
	assert test_cookie.name == 'test_name'
	assert test_cookie.value != ''
	// TODO test options
}

fn test_decoding() {
	opts := setup_basic_cookie_opts()
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
	opts := setup_basic_cookie_opts()
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

fn test_get_missing_cookie() {
	request := setup_request()
	get_cookie(request, 'test_name') or {
		assert true
		return
	}
}

fn test_get_set_cookie() {
	mut request := setup_request()
	opts := setup_basic_cookie_opts()
	test_cookie := new_cookie('test_name', 'test_value', opts) or {
		assert false
		return
	}
	request.cookies['test_name'] = test_cookie.value
	cookie := get_cookie(request, 'test_name') or {
		assert false
		return
	}
	assert cookie == test_cookie.value
}
