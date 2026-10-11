# 0003. Keep business rules in Custom Metadata

- **Status:** Accepted
- **Date:** 2026-10-10

## Context

SLA targets and routing rules change more often than code. Admins should be able to tune them, and every change should still be traceable.

## Decision

Store SLA targets in `SLA_Policy__mdt` and routing rules in `Routing_Rule__mdt`. Apex reads them at runtime; no target or queue name is hard-coded.

## Alternatives considered

| Option                    | Why not                                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------ |
| Hard-coded values in Apex | Every change needs a developer and a deployment.                                                 |
| Custom Settings           | Records are data, not metadata: they do not deploy with the source and are not versioned in Git. |
| Custom object records     | Same deployment problem, and reading them consumes SOQL queries.                                 |

## Consequences

- Records deploy with `sf project deploy start` and are reviewed in pull requests like code.
- `getAll()` reads Custom Metadata without consuming SOQL query limits.
- Tests can use the deployed records, or inject in-memory records for edge cases.
