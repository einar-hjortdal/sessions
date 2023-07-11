# Redis store

Redis store stores session data in a Redis instance. A cookie is given to the client, this cookie contains 
the session id used to match the client to its session data.

## Usage

Install with `v install Coachonko.sessions`

```V
// import the module
import coachonko.sessions

// Create options structs
redis_opts := redis.Options{
  // Refer to Coachonko/redis documentation
}
cookie_opts := sessions.CookieOptions{
  // Provide a secret to encrypt the value of the cookies.
  // It is recommended to use environment variables to store such secrets.
  secret: os.get_env(COOKIE_SECRET)
}
rso := RedisStoreOptions{
  redis_opts: redis_opts
  cookie_opts: cookie_opts
}

// Create a new RedisStore
redis_store := new_redis_store(rso)

// Use the RedisStore to create or load existing sessions
mut session := redis_store.new(request, 'demo')

// Edit sessions and then save the changes
// Session.values accepts a string: encode your data into a string using, for example, json.
session.values = json.encode(MySessionData, data) // MySessionData is defined by you, the user.

redis_store.save(response_header, session)
```
