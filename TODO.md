# TODO

## Stores

- vweb now has context thanks to [Casper64](https://github.com/Casper64) ([#18564](https://github.com/vlang/v/pull/18564)): 
  implement the vweb middleware, attach session data to `vweb.Context`.
- Implement the registry
- Redis store 
  - Requires a new Redis library. Work in progress [here](https://github.com/Coachonko/redis).
- Implement new stores:
  - File system. Useful for prototyping and simple apps with a single backend server.