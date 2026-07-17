module sessions

import net.http
import os
import time

const test_session_secret = 'testSessionSecret'
const test_firebird_container_name = 'test_firebird_server'
const test_firebird_port = '3051'
const test_firebird_user = 'test_user'
const test_firebird_root_password = 'test_root_password'
const test_firebird_password = 'test_password'
const test_firebird_database = 'test_database.fdb'
const test_firebird_host = 'localhost'
const test_firebird_url = 'firebird://${test_firebird_user}:${test_firebird_password}@${test_firebird_host}:${test_firebird_port}/var/lib/firebird/data/${test_firebird_database}'

fn firebird_test_container_firebird_start() ! {
	result :=
		os.execute('docker run --rm --detach --name=${test_firebird_container_name} --env=FIREBIRD_ROOT_PASSWORD=${test_firebird_root_password} --env=FIREBIRD_USER=${test_firebird_user} --env=FIREBIRD_PASSWORD=${test_firebird_password} --env=FIREBIRD_DATABASE=${test_firebird_database} --env=FIREBIRD_DATABASE_DEFAULT_CHARSET=UTF8 --publish=${test_firebird_port}:3050 firebirdsql/firebird')
	if result.exit_code != 0 {
		return error(result.output)
	}
}

fn firebird_test_container_firebird_clean() {
	result := os.execute('docker stop ${test_firebird_container_name}')
	if result.exit_code != 0 {
		eprintln(result.output)
	}
}

fn test_firebird_store() {
	firebird_test_container_firebird_start()!
	defer {
		firebird_test_container_firebird_clean()
	}
	time.sleep(5 * time.second) // need to wait for cotnainers startup. TODO fix magic number

	options := FirebirdStoreOptions{
		http_only: true
		path:      '/'
		secret:    test_session_secret
		secure:    true
		max_age:   1 * time.minute
	}
	mut store := new_firebird_store(options, test_firebird_url)!

	mut request := http.new_request(http.Method.get, 'http://some.path/', '')
	name := 'test_session'
	mut session := store.new(request, name)
	assert session.is_new

	session.values = 'test_value'
	store.save(mut request.header, session)!

	mut set_cookie_header := request.header.get(http.CommonHeader.set_cookie)!
	mut cookie_value := set_cookie_header.trim_string_left('${name}=').split(';')[0]
	mut cookie := http.Cookie{
		name:  name
		value: cookie_value
	}
	request.add_cookie(cookie)

	mut reloaded_session := store.new(request, name)
	assert reloaded_session.is_new == false
	assert reloaded_session.name == name
	assert reloaded_session.id == session.id
	assert reloaded_session.values == session.values

	new_value := 'new_test_value'
	reloaded_session.values = new_value
	store.save(mut request.header, reloaded_session)!
	set_cookie_header = request.header.get(http.CommonHeader.set_cookie)!
	cookie_value = set_cookie_header.trim_string_left('${name}=').split(';')[0]
	cookie = http.Cookie{
		name:  name
		value: cookie_value
	}
	request.add_cookie(cookie)
	reloaded_session = store.new(request, name)
	assert reloaded_session.values == new_value
}
