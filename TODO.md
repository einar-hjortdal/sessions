# TODO

## Stores

- Middleware function
  - Requires `http.Request` to have a Context in order to store the Registry.
- Implement `Registry`
- JWT store
  - Add filters to `validate_token`
- Redis store
- Implement new stores:
  - File system. Useful for prototyping and simple apps with a single backend server.