module main

import einar_hjortdal.sessions
import os
import json2
import veb

struct SessionValues {
	id    string
	flags map[string]string
}

@[heap]
pub struct App {
	veb.Middleware[Context]
mut:
	session_store &sessions.JsonWebTokenStore
}

pub struct Context {
	veb.Context
mut:
	session        sessions.Session
	session_values SessionValues
}

fn (mut app App) load_session_middleware(mut ctx Context) bool {
	// [/admin/auth; post] must accept unauthorized request to log in
	if ctx.req.url == '/admin/auth' && ctx.req.method == http.Method.post {
		return true
	}

	// loads session data
	ctx.session = app.session_store.new(ctx.req, os.getenv('SESSION_NAME'))
	if ctx.session.is_new {
		ctx.res.set_status(http.Status.unauthorized)
		ctx.text('Unauthorized')
		return false
	}

	// users-specific session data
	ctx.session_values = json2.decode[SessionValues](ctx.session.values) or {
		ctx.res.set_status(http.Status.internal_server_error)
		ctx.text('Failed to decode SessionValues')
		return false
	}

	return true
}

fn (mut app App) set_session_middleware(mut ctx Context) bool {
	// encode user-specific session data
	ctx.session.values = json2.encode(ctx.session_values, escape_unicode: true)

	// save session
	app.session_store.save(mut ctx.res.header, ctx.session) or {
		ctx.text('failed to save session')
		return false
	}

	return true
}

fn main() {
	mut session_store_options := sessions.JsonWebTokenStoreOptions{
		secret: os.getenv('SESSION_SECRET')
	}
	mut session_store := sessions.new_jwt_store(mut session_store_options) or { panic(err) }

	mut app := App{
		session_store: session_store
	}
	app.route_use('/admin/:path...', handler: app.load_session_middleware)
	app.route_use('/admin/:path...', handler: app.set_session_middleware, after: true)

	port := os.getenv(env_port).int()
	veb.run[App, Context](mut app, port)
}

@['/admin/auth/'; get]
fn (app &App) admin_auth_get(mut ctx Context) veb.Result {
	// manipulate ctx.session here
}
