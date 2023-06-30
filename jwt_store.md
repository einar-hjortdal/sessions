# JWT store

The JWT store puts all session data on the client in the form of a JWT, no session data is stored on 
the server.

## Usage

Install with `v install Coachonko.sessions`

```V
// import the module
import coachonko.sessions

// Create the options struct
jwtso := JsonWebTokenStoreOptions{
  // Provide a secret to encrypt the JWT.
  // It is recommended to use environment variables to store such secrets.
  secret: os.get_env(JWT_SECRET)
}

// Create a new store
jwt_store := new_jwt_store(jwtso)

// Use the JsonWebTokenStore to create or load existing sessions
mut session := jwt_store.new(request, 'demo')

// Edit sessions and then save the changes

// According to RFC7519, it is recommended to store the user ID in the field `sub`.
// All the other RFC7519 are managed by the store. Some can be set in the JsonWebTokenStoreOptions.
// Note: the `sub` field is not required and sessions can still hold data for unauthenticated users.
session.values['sub'] = '453636'

// Any other field is up to you:
session.values['subscribed'] = false
jwt_store.save(response_header, session)
```
