module sessions

import json
import net.http
import time
import einar_hjortdal.luuid
import einar_hjortdal.firebird

pub const firebird_table = 'einar_hjortdal_sessions'

// Stores the session id in a cookie
pub struct FirebirdStore {
	CookieOptions
mut:
	gen  &luuid.Generator
	conn &firebird.Connection
}

// if an existing connection is provided it will be used, otherwise a new connection will be started using the given url.
pub struct FirebirdStoreOptions {
	CookieOptions
pub:
	url    string
pub mut:
	connection ?&firebird.Connection
}

fn (o FirebirdStoreOptions) get_connection() !&firebird.Connection {
	if o.connection != none {
		return o.connection
	}
	return firebird.new_connection(o.url)!
}

fn (mut store FirebirdStore) table_exists() ! {
	mut tx := store.conn.start_transaction(firebird.isolation_level_read_commited)!

	// this query returns an error if the table does not exist
	tx.execute('SELECT COUNT(*) OVER() FROM ${firebird_table}') or {
		tx.rollback() or {}
		return err
	}

	tx.rollback() or {}
}

fn (mut store FirebirdStore) table_create() ! {
	mut tx := store.conn.start_transaction(firebird.isolation_level_read_commited)!

	tx.execute('CREATE TABLE ${firebird_table} (
		id BINARY(16) NOT NULL,
		encoded BLOB SUB_TYPE TEXT NOT NULL,
		expires_at TIMESTAMP NOT NULL,
		CONSTRAINT "${store.gen.v1()}" PRIMARY KEY (id)
		)') or {
		tx.rollback() or {}
		return err
	}

	tx.commit()!
}

pub fn new_firebird_store(options FirebirdStoreOptions) !&FirebirdStore {
	mut store := &FirebirdStore{
		CookieOptions: options.CookieOptions
		gen:           luuid.new_generator()
		conn:          options.get_connection()!
	}
	store.table_exists() or { store.table_create()! }
	return store
}

fn (mut store FirebirdStore) new_firebird_session(name string) Session {
	mut session := new_session(name)
	session.id = store.gen.v1()
	return session
}

fn (mut store FirebirdStore) load(session_id string) !Session {
	session_id_bin := luuid.to_bytes(session_id)!

	mut tx := store.conn.start_transaction(firebird.isolation_level_read_commited)!

	data := tx.execute('SELECT encoded FROM ${firebird_table} WHERE id = ?', session_id_bin) or {
		tx.rollback() or {}
		return err
	}

	tx.rollback() or {}

	rows := data.rows()
	if rows.len == 0 {
		return error('No session exists with the given session_id')
	}

	v := rows[0].values()
	encoded, _ := v[0].get_string()!
	return json.decode(Session, encoded)!
}

// also deletes all other expired sessions
fn (mut store FirebirdStore) delete(session_id string) ! {
	session_id_bin := luuid.to_bytes(session_id)!

	mut tx := store.conn.start_transaction(firebird.isolation_level_read_commited)!

	tx.execute('DELETE FROM ${firebird_table} WHERE id = ?', session_id_bin) or {
		tx.rollback() or {}
		return err
	}

	tx.execute('DELETE FROM ${firebird_table} WHERE expires_at < CURRENT_TIMESTAMP') or {
		tx.rollback() or {}
		return err
	}

	tx.commit()!
}

// creates or updates a session
fn (mut store FirebirdStore) merge(session Session) ! {
	session_id_bin := luuid.to_bytes(session.id)!
	encoded := json.encode(session)

	mut tx := store.conn.start_transaction(firebird.isolation_level_read_commited)!

	tx.execute('MERGE INTO ${firebird_table} t 
		USING (
			SELECT(
				CAST(? AS BINARY(16)) AS id,
				CAST(? AS BLOB SUB_TYPE TEXT) AS encoded
				FROM RDB\$DATABASE
			)
		) s
		ON t.id = s.id
		WHEN MATCHED THEN
			UPDATE SET
				t.encoded = s.encoded,
				t.expires_at = DATEADD(${i32(store.max_age / time.second)} SECOND TO CURRENT_TIMESTAMP
		WHEN NOT MATCHED THEN
			INSERT (id, encoded, updated_at) 
			VALUES (s.id, s.encoded, CURRENT_TIMESTAMP)',
		session_id_bin, encoded) or {
		tx.rollback() or {}
		return err
	}

	tx.commit()!
}

pub fn (mut store FirebirdStore) get(mut request http.Request, name string) Session {
	return Session{}
}

pub fn (mut store FirebirdStore) new(request http.Request, name string) Session {
	request_cookie := get_cookie_value(request, name) or { return store.new_firebird_session(name) }

	session_id := decode_cookie_value(request_cookie, store.secret) or {
		return store.new_firebird_session(name)
	}

	session := store.load(session_id) or { return store.new_firebird_session(name) }

	return session
}

pub fn (mut store FirebirdStore) save(mut response_header http.Header, mut session Session) ! {
	if store.CookieOptions.max_age <= 0 || session.to_prune {
		store.delete(session.id)!
		new_cookie_opts := cookie_opts_del(store.CookieOptions)
		cookie := new_cookie(session.name, '', new_cookie_opts)!
		set_cookie(mut response_header, cookie)!
	} else {
		store.merge(session)!
		cookie := new_cookie(session.name, session.id, store.CookieOptions)!
		set_cookie(mut response_header, cookie)!
	}
}
