# TODO

## Stores

- vweb now has context thanks to [Casper64](https://github.com/Casper64) ([#18564](https://github.com/vlang/v/pull/18564)): 
  implement registry and vweb middleware, attach session data to `vweb.Context`.
- Challenge issued by [JalonSolov](https://github.com/JalonSolov): remove `json.Any`.
  - In JWT Store, RFC7519 claims must be contained in the payload, the user of this library also has 
  to be able to set the `sub` claim. Then, after decoding the json, `iss`, `aud`, `exp`, `nbf`, `iat` 
  and `jti` are used by the library itself to validate the token. These claims should also remain available 
  to the user to perform further operations on them if needed. How can json.Any be removed in such situation?
- Redis store 
  - Requires a new Redis library. Work in progress [here](https://github.com/Coachonko/redis).
  - Use cookie headers, not `Context.get_cookie`
  - `request.cookies` was removed from `net.http`
  - Cookie signature should be done on base64url encoded session id.
- Implement new stores:
  - File system
