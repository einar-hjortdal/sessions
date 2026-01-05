# sessions

sessions is a web-framework-agnostic library for managing sessions in web applications written in the 
V language.

It features a simple API: just name a session, everything else is handled internally.

## First-party `Store` implementations

- [JWT](#JWT)
- [Cookie](#Cookie)
- [Redict](#Redict) (Compatible with Redis <=7.2.4)
- [FirebirdSQL](#FirebirdSQL)

### JWT

- All session data is stored on the client in the form of a JWT.
- No data is stored on the server.
- Supports multiple sessions per request.

Install with `v install einar-hjortdal.sessions`

```v
// import the module
import einar_hjortdal.sessions

// Create the options struct
// For more information about this struct, please look at the source.
mut jwtso := JsonWebTokenStoreOptions{
  // Provide a secret to encrypt the JWT.
  // It is recommended to use environment variables to store such secrets.
  secret: os.get_env('JWT_SECRET')
}

// Create a new store
jwt_store := new_jwt_store(mut jwtso)

// Use the JsonWebTokenStore to create or load existing sessions.
// Note: More than one session can be stored, each is stored in its own custom HTTP header.
mut session := jwt_store.new(request, 'demo')

// Edit sessions and then save the changes
// Session.values can only contain a string: you must encode your data to string.
// Structs can be encoded to json, but any encoding that outputs a string is fine.
session.values = 'some string'

jwt_store.save(response_header, session)
```

### Cookie

- All session data is stored on the client in the form of a Cookie
- No session data is stored on the server.
- Supports multiple sessions per request.

Install with `v install einar-hjortdal.sessions`

```V
// import the module
import einar_hjortdal.sessions

// Create the options struct
// For more information about this struct, please look at the source.
cso :=  := CookieStoreOptions{
		cookie_opts: CookieOptions{
      // Provide a secret to encrypt the cookie.
      // It is recommended to use environment variables to store such secrets.
			secret: os.get_env(COOKIE_SECRET)
		}
	}

// Create a new store
cookie_store := new_cookie_store(cso)

// Use the CookieStore to create or load existing sessions
// Note: More than one session can be stored, each is stored in its own cookie.
mut session := cookie_store.new(request, 'demo')

// Edit sessions and then save the changes
// Session.values can only contain a string: you must encode your data to string.
// Structs can be encoded to json, but any encoding that outputs a string is fine.
session.values = 'some string'

cookie_store.save(response_header, session)
```

### Redict

- All session data is stored in a Redict instance. Relies on [einar-hjortdal/redict](https://github.com/einar-hjortdal/redict).
- Session ID is stored on the client using a cookie or a JWT.
- Supports multiple sessions per request.

Install with `v install einar-hjortdal.sessions`

#### Cookie

A cookie is given to the client, this cookie contains a session id.

```V
// import the module
import einar_hjortdal.sessions

// Create options structs
mut ro := redict.Options{
  // Refer to einar_hjortdal/redict documentation
}
co := sessions.CookieOptions{
  // Provide a secret to encrypt the value of the cookies.
  // It is recommended to use environment variables to store such secrets.
  secret: os.get_env(COOKIE_SECRET)
  // Set the duration of the sessions.
  // If not set, cookies will have a Max-Age of 0, and they will be immediately deleted by the client.
  max_age: 30 * time.minute
  // For more information, check out the cookie.v file
}
mut rso := sessions.RedictStoreOptions{
  // For information, check out the redict_store.v file
}

// Create a new RedictStore
store := sessions.new_redict_store_cookie(mut rso, co, mut ro)

// Use the RedictStore to create or load existing sessions
mut session := store.new(request, 'demo')

// Edit sessions and then save the changes
// Session.values accepts a string: encode your data into a string using, for example, json.
session.values = json.encode(MySessionData, data) // MySessionData is defined by you, the user.

store.save(mut response_header, mut session)
```

#### JWT

A JWT is given to the client as a *custom header*, the `sid` claim contains the session id.

```V
// import the module
import einar_hjortdal.sessions

mut rso := RedictStoreOptions{}
mut jwto := JsonWebTokenOptions{
  secret: os.get_env(COOKIE_SECRET)
  // For more information, check out the jwt.v file
}
mut ro := redict.Options{}
store := new_redict_store_jwt(mut rso, mut jwto, ro)!

// Create (or load) and save sessions as with the cookie version
```

### FirebirdSQL

Sets a cookie with the session id on the client, all data is stored in a FirebirdSQL table.

```V
// import the module
import einar_hjortdal.sessions

store := new_firebird_store(FirebirdStoreOptions{
  CookieOptions{
    http_only: true
    path:      '/'
    secret:    'A strong secret'
    secure:    true
    max_age:   24 * time.hour
  }
  url: 'firebird://user:password@localhost:3050/var/lib/firebird/data/firebird.fdb'
})!

// Create (or load) and save sessions as with the cookie version
```

## Third-party `Store` implementations

Submit a pull request to have your implementation listed here.

## Notes

- It is important to implement race condition mitigation strategies within the route handler, such as 
  *optimistic locking with version number*.

## Development

- [Issues](https://github.com/einar-hjortdal/firebird/issues)
- [TODO.md](./TODO.md)
- [CONTRIBUTING.md](./CONTRIBUTING.md)
- [ROADMAP.md](./READMAP.md)
