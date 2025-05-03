module main

import einar_hjortdal.sessions
import os

@[heap]
pub struct App {
	veb.Middleware[Context]
mut:
	session_store &sessions.JsonWebTokenStore
}

pub struct Context {
	veb.Context
mut:
	session sessions.Session
}

fn (mut app App) load_session_middleware(mut ctx Context) bool {
	// [/admin/auth; post] must accept unauthorized request to log in
	if ctx.req.url == '/admin/auth' && ctx.req.method == http.Method.post {
		return true
	}

	ctx.session = app.session_store.new(ctx.req, os.getenv('SESSION_NAME'))
	if ctx.session.is_new {
		ctx.text('Unauthorized')
		return false
	}

	return true
}

fn (mut app App) set_session_middleware(mut ctx Context) bool {
	app.session_store.save(mut ctx.res.header, mut ctx.session) or {
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
