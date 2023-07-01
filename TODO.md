# TODO

## Stores

- vweb now has context thanks to [Casper64](https://github.com/Casper64) ([#18564](https://github.com/vlang/v/pull/18564)): 
  implement registry and vweb middleware, attach session data to `vweb.Context`.
- Redis store 
  - Requires a new Redis library. Work in progress [here](https://github.com/Coachonko/redis).
  - Split cookie from redis. Cookie can be used by other stores.
    - Use cookie headers, not `Context.get_cookie`
    - `request.cookies` was removed from `net.http`
    - Cookie signature should be done on base64url encoded session id.
- Implement new stores:
  - File system. Useful for prototyping and simple apps with a single backend server.
- Flashes should be stored as `[]string` in Session.flashes