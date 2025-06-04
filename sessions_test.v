module sessions

fn test_new_session() {
	session := new_session('test')
	assert session.name == 'test'
}

fn test_new_flash() {
	mut session := new_session('test')
	session.add_flash('message', 'test_message')
	assert session.flashes.len == 1
	assert session.flashes[0].message == 'test_message'
}
