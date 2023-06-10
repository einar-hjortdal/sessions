module sessions

import arrays
import x.json2 as json

// new_flash adds a flash to the session.
pub fn (mut session Session) new_flash(value json.Any) {
	flashes_key := 'flashes'
	if data := session.values[flashes_key] {
		if data is []json.Any {
			session.values[flashes_key] = arrays.concat(data, value)
		} else {
			mut new_array := []json.Any{}
			new_array << data
			session.values[flashes_key] = arrays.concat(new_array, value)
		}
	} else {
		session.values[flashes_key] = value
	}
}

// get_flashes returns flashes from the session, if any are set.
pub fn (mut session Session) get_flashes() ?json.Any {
	flashes_key := 'flashes'
	if data := session.values[flashes_key] {
		session.values.delete(flashes_key)
		return data
	}
	return none
}
