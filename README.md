# sessions

sessions is a library for managing sessions in web applications written in the V language. 
<!--
It is framework-agnostic but it also features a middleware function for vweb.

The sessions middleware verifies the signature of the cookie and acts accordingly.
  - If the cookie is missing or has an invalid signature, generates a new session and sets a new cookie.
  - If the signature is valid, retrieves session data from a `Store` and makes it available to the route 
  handler.
-->

Session cookies only contain the session ID, all the session data is stored on `Store`s. 

The only supported `Store` at the moment is Redis and relies on [patrickpissurno/vredis](https://github.com/patrickpissurno/vredis). This `Store` is developed against [KeyDB](https://github.com/Snapchat/KeyDB).

## Usage

Install with `v install Coachonko.sessions`

```V
import sessions

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

## Notes

- It is important to implement race condition mitigation strategies within the route handler, such as 
  *optimistic locking with version number*.
