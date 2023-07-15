# Cookie store

The Cookie store puts all session data on the client in the form of a Cookie, no session data is stored 
on the server.

## Usage

Install with `v install Coachonko.sessions`

```V
// import the module
import coachonko.sessions

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
