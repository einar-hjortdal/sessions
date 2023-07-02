module sessions

pub struct Session {
	// name is the property utilized by users of the sessions library.
	name string
mut:
	id string
	// values contains the user-data for the session.
	// In order to store complex data as a string, data can be encoded, for example as JSON.
	values string
	is_new bool
	// flashes []Flash
}

// new_session is called by session stores to create a new session instance.
fn new_session(name string) Session {
	return Session{
		name: name
		is_new: true
	}
}
