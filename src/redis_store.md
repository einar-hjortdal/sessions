# Redis store

Redis store stores session data in a Redis instance. To match requests to their session data, there 
are two options: 
1. A cookie is given to the client, this cookie contains a session id.
  This option is best suited to server-rendered web applications.
2. A JWT is given to the client as a custom header, the `sid` claim contains the session id.
  This option is best suited for client-rendered web applications.

## Usage

Install with `v install Coachonko.sessions`

```V
// import the module
import coachonko.sessions

// Create options structs
mut ro := redis.Options{
  // Refer to Coachonko/redis documentation
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
mut rso := sessions.RedisStoreOptions{
  // For information, check out the redis_store.v file
}

// Create a new RedisStore
store := sessions.new_redis_store_cookie(mut rso, co, mut ro)

// Use the RedisStore to create or load existing sessions
mut session := store.new(request, 'demo')

// Edit sessions and then save the changes
// Session.values accepts a string: encode your data into a string using, for example, json.
session.values = json.encode(MySessionData, data) // MySessionData is defined by you, the user.

store.save(mut response_header, mut session)
```
