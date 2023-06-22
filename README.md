# sessions

sessions is a library for managing sessions in web applications written in the V language. 

<!--
It is framework-agnostic but it also features a middleware function for vweb.

The sessions middleware verifies the signature of the cookie and acts accordingly.
  - If the cookie is missing or has an invalid signature, generates a new session and sets a new cookie.
  - If the signature is valid, retrieves session data from a `Store` and makes it available to the route 
  handler.
-->

## Redis store features

> Broken: see [#25](https://github.com/patrickpissurno/vredis/issues/25). Furthermore, the package relied on unmerged PR [#26](https://github.com/patrickpissurno/vredis/pull/26)

- Create a new connection pool or use an existing one
- Unlimited or limited session data size
- Refresh `EXPIRE` on each request or only when session data is changed

## Usage

For each Store, refer to its own documentation.

## Notes

- It is important to implement race condition mitigation strategies within the route handler, such as 
  *optimistic locking with version number*.
