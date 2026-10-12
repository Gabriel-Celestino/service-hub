# 0008. Enforce user permissions in UI controllers, run automation in system mode

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

The same data is read in two very different situations. Automation (triggers, the escalation job) must see every case and milestone to keep SLAs correct, whoever caused the change. Lightning components show data to a person, who must only see what their permissions allow.

## Decision

- **Automation** (services called from triggers and batch jobs) runs in system mode. Services use `inherited sharing`; the batch is explicitly `without sharing`.
- **UI controllers** (`CaseSlaController`, `SlaConsoleController`) are `with sharing`, and every query they trigger runs `WITH USER_MODE` (or `AccessLevel.USER_MODE` for dynamic SOQL), which enforces sharing, object permissions and field-level security.
- UI-facing queries live in the selectors as separate `selectVisible...` / `...ForConsole` methods, so it is obvious at the call site which mode a query uses.
- Controllers return small view classes, never raw SObjects.

## Alternatives considered

| Option                                    | Why not                                                                                                       |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `WITH SECURITY_ENFORCED`                  | Older: no sharing enforcement, and it fails on the first inaccessible field instead of reporting all of them. |
| `Security.stripInaccessible`              | Silently drops fields; the UI would show blanks instead of a clear permission error.                          |
| One selector method with a mode parameter | Hides the security decision inside a flag that is easy to pass wrong.                                         |

## Consequences

- The `Service_Hub_Agent` permission set is the single source of access to the project's fields, Apex classes, app and tab.
- Controller tests run as a dedicated agent user with that permission set, so a missing permission fails a test instead of production.
- The console ranks cases from the milestones the agent can see, so it never leaks deadlines of inaccessible cases.
