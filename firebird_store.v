module sessions

import json2
import net.http
import time
import einar_hjortdal.luuid
import einar_hjortdal.firebird

pub const firebird_table = 'einar_hjortdal_sessions'
const isolation_level = firebird.isolation_level_read_commited

// Stores the session id in a cookie
pub struct FirebirdStore {
	CookieOptions
	refresh_expire bool
mut:
	gen    &luuid.Generator
	conn   ?&firebird.Connection
	client ?&firebird.Client
}

fn (mut s FirebirdStore) start_transaction() !&firebird.Transaction {
	if conn := s.conn {
		return conn.start_transaction(isolation_level)!
	}

	if mut client := s.client {
		return client.start_transaction(isolation_level)!
	}

	return error('No connection/client available')
}

fn (mut store FirebirdStore) table_exists() ! {
	mut tx := store.start_transaction()!

	// this query returns an error if the table does not exist
	tx.execute('SELECT COUNT(*) FROM ${firebird_table}') or {
		tx.rollback() or {}
		return err
	}

	tx.rollback() or {}
}

fn (mut store FirebirdStore) table_create() ! {
	mut tx := store.start_transaction()!

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

fn (mut store FirebirdStore) init() ! {
	store.table_exists() or { store.table_create()! }
}

// if an existing connection/client is provided it will be used, otherwise a new client will be started using the given url.
pub struct FirebirdStoreOptions {
	CookieOptions
pub:
	refresh_expire bool
}

fn (o FirebirdStoreOptions) new_store_with_connection(mut conn firebird.Connection) !&FirebirdStore {
	mut store := &FirebirdStore{
		CookieOptions:  o.CookieOptions
		refresh_expire: o.refresh_expire
		gen:            luuid.new_generator()
		conn:           conn
	}
	store.init()!
	return store
}

fn (o FirebirdStoreOptions) new_store_with_client(mut client firebird.Client) !&FirebirdStore {
	mut store := &FirebirdStore{
		CookieOptions:  o.CookieOptions
		refresh_expire: o.refresh_expire
		gen:            luuid.new_generator()
		client:         client
	}
	store.init()!
	return store
}

pub fn new_firebird_store(options FirebirdStoreOptions, url string) !&FirebirdStore {
	mut client := firebird.new_client(firebird.ClientConfig{
		url: url
	})!
	return options.new_store_with_client(mut client)!
}

pub fn new_firebird_store_from_client(options FirebirdStoreOptions, mut client firebird.Client) !&FirebirdStore {
	return options.new_store_with_client(mut client)!
}

pub fn new_firebird_store_from_connection(options FirebirdStoreOptions, mut conn firebird.Connection) !&FirebirdStore {
	return options.new_store_with_connection(mut conn)!
}

fn (mut store FirebirdStore) new_firebird_session(name string) Session {
	mut session := new_session(name)
	session.id = store.gen.v1()
	return session
}

fn (mut store FirebirdStore) load(session_id string) !Session {
	session_id_bin := luuid.to_bytes(session_id)!

	mut tx := store.start_transaction()!

	if store.refresh_expire {
		tx.execute('UPDATE ${firebird_table}
			SET expires_at = DATEADD(${i32(store.max_age / time.second)} SECOND TO CURRENT_TIMESTAMP
			WHERE id = ?')!
	}

	data := tx.execute('SELECT encoded FROM ${firebird_table} WHERE id = ?', session_id_bin) or {
		tx.rollback() or {}
		return err
	}

	if store.refresh_expire {
		tx.commit() or {}
	} else {
		tx.rollback() or {}
	}

	rows := data.rows()
	if rows.len == 0 {
		return error('No session exists with the given session_id')
	}

	v := rows[0].values()
	encoded, _ := v[0].get_string()!
	return json2.decode[Session](encoded)!
}

// also deletes all other expired sessions
fn (mut store FirebirdStore) delete(session_id string) ! {
	session_id_bin := luuid.to_bytes(session_id)!

	mut tx := store.start_transaction()!

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
	encoded := json2.encode(session, escape_unicode: true)

	mut tx := store.start_transaction()!

	tx.execute('MERGE INTO ${firebird_table} t
		USING (
			SELECT
				CAST(? AS BINARY(16)),
				CAST(? AS BLOB SUB_TYPE TEXT),
				DATEADD(${i32(store.max_age / time.second)} SECOND TO CURRENT_TIMESTAMP)
				FROM RDB\$DATABASE
		) s (id, encoded, expires_at)
		ON t.id = s.id
		WHEN MATCHED THEN
			UPDATE SET
				t.encoded = s.encoded,
				t.expires_at = s.expires_at
		WHEN NOT MATCHED THEN
			INSERT (id, encoded, expires_at)
			VALUES (s.id, s.encoded, s.expires_at)',
		session_id_bin, encoded) or {
		tx.rollback() or {}
		return err
	}

	tx.commit()!
}

pub fn (mut store FirebirdStore) new(request http.Request, name string) Session {
	request_cookie := get_cookie_value(request, name) or { return store.new_firebird_session(name) }

	session_id := decode_cookie_value(request_cookie, store.secret) or {
		return store.new_firebird_session(name)
	}

	mut session := store.load(session_id) or { return store.new_firebird_session(name) }
	session.is_new = false
	return session
}

pub fn (mut store FirebirdStore) save(mut response_header http.Header, session Session) ! {
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
