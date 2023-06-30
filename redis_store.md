# Redis store

Redis store stores session data in a Redis instance. A cookie is given to the client, this cookie contains 
a session id used to match the client to its session data.

## Usage

Install with `v install Coachonko.sessions`

```V
// import the module
import coachonko.sessions

// Create options structs
redis_pool_opts := redis.PoolOpts{
  // Refer to vredis documentation
}
cookie_opts := sessions.CookieOptions{
  // Provide a secret to encrypt the value of the cookies.
  // It is recommended to use environment variables to store such secrets.
  secret: os.get_env(COOKIE_SECRET)
}
rso := RedisStoreOptions{
  pool_opts: redis_pool_opts
  cookie_opts: cookie_opts
}

// Create a new RedisStore
redis_store := new_redis_store(rso)

// Use the RedisStore to create or load existing sessions
mut session := redis_store.new(request, 'demo')
// Edit sessions and then save the changes
session.values['subscribed'] = false
redis_store.save(response_header, session)
```
