# Contributing

## Branches

- `main` is always deployable and protected: changes arrive only through pull requests.
- Work happens on short-lived branches named `<type>/<short-description>`, for example `feat/sla-engine` or `fix/routing-fallback`.

## Commit messages

Commits follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <summary in the imperative>
```

| Type       | Use for                              |
| ---------- | ------------------------------------ |
| `feat`     | A new capability                     |
| `fix`      | A bug fix                            |
| `test`     | Adding or fixing tests               |
| `docs`     | Documentation and ADRs               |
| `refactor` | Code change with no behavior change  |
| `chore`    | Tooling, dependencies, configuration |
| `ci`       | Pipeline changes                     |

Examples: `feat(sla): pause milestones while waiting on customer`, `docs(adr): record platform events decision`.

## Pull requests

1. Open the PR with the template filled in.
2. The branch must deploy to a fresh scratch org and all Apex and Jest tests must pass.
3. Apex coverage stays at or above 90%, with meaningful assertions.
4. Any significant design choice comes with a new ADR in `docs/adr/`.

## Code style

- Prettier formats Apex, LWC, XML and Markdown; a pre-commit hook runs it on staged files.
- Metadata API names, labels, descriptions and code comments are in English.
