# Contributing

Please follow these standards

## Git workflow

1. Fork the project and clone your fork to your development environment
2. Add the original repository as an additional git remote called "upstream"
3. Create a new branch
  - The branch called `live` is the branch that goes live.
  - The branch called `pending` is the branch used for changes that are pending to go live.
  - New features are branched from `live` and merged into `pending` when ready.
  - Bug fixes are branched from `live` and then merged into both `live` and `pending`.

4. Write your code, test it and make sure it works
5. Commit your changes
6. Pull the latest code from upstream into your branch 

  Make sure your changes do not conflict with the original repository.

7. Push changes to the remote "origin" (your repository)
8. Create a pull request
  - If the pull request addresses an issue, tag the related issue

## V

- No enums.
- No logical assignment operators.
- No static methods.
- No lambdas.
- No `@[required]` attribute in struct definitions.
- Use `arrays.concat` instead of `<<`.

### FirebirdSQL

- Uppercase for keywords, data types. Lowercase all other identifiers.
- Use `REAL` and `DOUBLE PRECISION` for floating point types.
- Use `CHAR` for strings with expected exact lengths.
- Use `VARCHAR` for strings with expected maximum lengths, for strings with default values, and for 
  strings that are in an `INDEX` or `UNIQUE` constraint.
- Use `TEXT` for unknown-length strings.
