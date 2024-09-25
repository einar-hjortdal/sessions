# sessions

sessions is a web-framework-agnostic library for managing sessions in web applications written in the 
V language.

## Stores

- JWT ([documentation](./src/jwt_store.md))
- Cookie ([documentation](./src/cookie_store.md))
- Redict ([documentation](./src/redict_store.md), compatible with Redis)

## Notes

- It is important to implement race condition mitigation strategies within the route handler, such as 
  *optimistic locking with version number*.
- Both `JsonWebTokenStore` and `RedictStoreJsonWebToken` use custom headers, this allows to store multiple 
  sessions on one response.

## Development

- [Issues](https://github.com/einar-hjortdal/firebird/issues)
- [TODO.md](./TODO.md)
- [CONTRIBUTING.md](./CONTRIBUTING.md)
