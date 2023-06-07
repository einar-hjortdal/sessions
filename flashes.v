module sessions

// new_flash adds a flash to the session.
pub fn (session Session) new_flash(value json.Any) {
	flashes_key := 'flashes'
	if data := session.values[flashes_key] {
		data << value // https://github.com/vlang/v/discussions/18370
		session.values[flashes_key] = data
	} else {
		mut new_array := []json.Any{}
		new_array << value
		session.values[flashes_key] = new_array
	}
}

// get_flashes returns flashes from the session, if any are set.
pub fn (session Session) get_flashes() ?json.Any {
	flashes_key := 'flashes'
	if data := session.values[flashes_key] {
		// Drop the flashes and return it.
		session.values.delete(flashes_key)
		return data
	}
	return none
}
