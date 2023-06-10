module sessions

import x.json2 as json

pub struct Session {
	name  string
	store Store
mut:
	id string
	// values contains the user-data for the session.
	values map[string]json.Any
	is_new bool
}

// new_session is called by session stores to create a new session instance.
fn new_session(store Store, name string) Session {
	return Session{
		name: name
		store: store
	}
}
