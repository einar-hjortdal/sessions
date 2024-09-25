import vweb // TODO vweb is deprecated, move to veb
import net.http
import json
import einar_hjortdal.sessions
import einar_hjortdal.redict

const constant_admin_session_name = 'Admin'
const constant_header_key = 'Einar-${constant_admin_session_name}'

/*
*
* VWeb stuff
*
*/
pub struct App {
	vweb.Context
mut:
	sessions_struct Sessions @[vweb_global]
}

pub fn (mut app App) before_request() {
	handle_cors(mut app)
	// Send response automatically to all OPTIONS requests.
	if app.req.method == http.Method.options {
		app.ok('')
	}
}

fn handle_cors(mut app App) {
	frontend_domain := 'http://localhost:29100'
	origin := app.get_header('Origin')
	if origin == frontend_domain {
		app.add_header('Access-Control-Allow-Origin', origin)
		app.add_header('Access-Control-Allow-Headers', 'Content-Type')
		app.add_header('Access-Control-Expose-Headers', constant_header_key)
	}
}

struct AdminAuthPostRequest {
	email    string
	password string
}

@['/admin/auth'; post]
pub fn (mut app App) admin_auth_post() vweb.Result {
	body := json.decode(AdminAuthPostRequest, app.req.data) or {
		app.set_status(422, 'Invalid request')
		e := {
			'code': '5'
			'info': 'Could not decode AdminAuthPostRequest'
		}
		return app.json(e)
	}

	mut new_session := app.sessions_struct.store.new(app.req, app.sessions_struct.admin_session_name)
	new_session.values = '${body}'
	app.sessions_struct.store.save(mut app.header, mut new_session) or { panic(err) }

	return app.json({
		'code': '1'
		'info': 'success'
	})
}

/*
*
* Sessions stuff
*
*/
pub struct Sessions {
pub:
	admin_session_name string
pub mut:
	store sessions.Store
}

pub fn new_sessions_store() !&sessions.Store {
	// https://github.com/einar_hjortdal/sessions/blob/pending/src/jwt.v
	mut jwto := sessions.JsonWebTokenOptions{
		secret: 'some-dummy-secret'
	}

	// https://github.com/einar_hjortdal/sessions/blob/pending/src/redict_store.v
	mut rso := sessions.RedictStoreOptions{}

	// https://github.com/einar_hjortdal/redict/blob/pending/src/options.v
	mut ro := redict.Options{
		address: 'localhost:29400'
	}

	return sessions.new_redict_store_jwt(mut rso, mut jwto, mut ro)!
}

fn main() {
	new_store := new_sessions_store() or { panic(err) }

	new_sessions_struct := &Sessions{
		admin_session_name: constant_admin_session_name
		store:              new_store
	}

	mut app := &App{
		sessions_struct: new_sessions_struct
	}

	vweb.run_at(app, vweb.RunParams{
		port: 29000
	}) or {
		panic(err)
		return
	}
}
