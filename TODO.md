# TODO

## Stores

- vweb now has context thanks to [Casper64](https://github.com/Casper64) ([#18564](https://github.com/vlang/v/pull/18564)): 
  implement registry and vweb middleware, attach session data to `vweb.Context`.
- Redis store 
  - Requires a new Redis library. Work in progress [here](https://github.com/Coachonko/redis).
- Implement new stores:
  - Cookie store. Stores entire sessions in cookies.
  - File system. Useful for prototyping and simple apps with a single backend server.