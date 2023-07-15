# Redis store

Redis store stores session data in a Redis instance. A cookie is given to the client, this cookie contains 
the session id used to match the client to its session data.

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
rso := sessions.RedisStoreOptions{
  // For information, check out the redis_store.v file
}

// Create a new RedisStore
store := sessions.new_redis_store(rso, co, mut ro)

// Use the RedisStore to create or load existing sessions
mut session := store.new(request, 'demo')

// Edit sessions and then save the changes
// Session.values accepts a string: encode your data into a string using, for example, json.
session.values = json.encode(MySessionData, data) // MySessionData is defined by you, the user.

store.save(mut response_header, mut session)
```
