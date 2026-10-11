# 0001. Use the standard Case object for tickets

- **Status:** Accepted
- **Date:** 2026-10-10

## Context

Service Hub manages customer tickets. Salesforce offers a standard `Case` object for exactly this, but a custom `Ticket__c` object would give full control over its fields and behavior.

## Decision

Tickets are standard `Case` records, extended with custom fields and child objects.

## Alternatives considered

| Option                    | Why not                                                                                                                                                                          |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Custom `Ticket__c` object | Rebuilds what the platform already offers: queues, assignment, Service Console, case reports, email-to-case and Experience Cloud case pages all work with `Case` out of the box. |

## Consequences

- Queues, list views, reports and the Service Console work with no extra code.
- Case standard picklists (Status, Priority, Origin) are Standard Value Sets, deployed as `StandardValueSet` metadata rather than field definitions.
- Some standard behavior (for example, the closed flag on statuses) must be respected by the SLA engine.
