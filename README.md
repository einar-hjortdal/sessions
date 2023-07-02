# sessions

sessions is a library for managing sessions in web applications written in the V language.

<!-- Framework-agnostic but also features a middleware function for vweb. -->

## JWT store

Documented [here](./jwt_store.md)

## Redis store

> Broken: see [#25](https://github.com/patrickpissurno/vredis/issues/25). Furthermore, the package relied 
  on unmerged PR [#26](https://github.com/patrickpissurno/vredis/pull/26). New Redis library is being 
  developed [here](https://github.com/Coachonko/redis)

Documented [here](./redis_store.md)

## Notes

- It is important to implement race condition mitigation strategies within the route handler, such as 
  *optimistic locking with version number*.
