# sessions

sessions is a web-framework-agnostic library for managing sessions in web applications written in the 
V language.

## Stores

- JWT ([documentation](./jwt_store.md))
- Cookie ([documentation](./cookie_store.md))
- Redis ([documentation](./redis_store.md))
  Note: currently broken: see [#25](https://github.com/patrickpissurno/vredis/issues/25). Furthermore, 
  the package relied on unmerged PR [#26](https://github.com/patrickpissurno/vredis/pull/26). New Redis 
  library is being developed [here](https://github.com/Coachonko/redis)

## Notes

- It is important to implement race condition mitigation strategies within the route handler, such as 
  *optimistic locking with version number*.
