module sessions

pub struct Session {
	// name is the property utilized by users of the sessions library.
	name string
mut:
	id string
	// values contains the user-data for the session.
	// In order to store complex data as a string, data can be encoded, for example as JSON.
	values  string
	is_new  bool
	flashes []Flash
}

// new_session is called by session stores to create a new session instance.
fn new_session(name string) Session {
	return Session{
		name: name
		is_new: true
	}
}

/*
*
*
* Flashes
*
*
*/

// Flash is a short-lived message often used for displaying notifications or feedback to users.
// It provides a way to communicate a temporary message between requests.
pub struct Flash {
	kind    string
	message string
mut:
	consumed bool
}

// new_flash adds a flash to the session.
pub fn (mut session Session) add_flash(kind string, message string) {
	new_flash := Flash{
		kind: kind
		message: message
		consumed: false
	}
	session.flashes << new_flash
}
