# TODO

## Stores

- Check why `session` is mutable in the `Store` interface. Make immutable if possible.
- Middleware function
  - Requires `http.Request` to have a Context in order to store the `Registry`.
- JWT store
  - Add filters to `validate_token`
- Implement new stores:
  - File system. Useful for prototyping and simple apps with a single backend server.