# 0005. Notify external systems through Platform Events

- **Status:** Accepted
- **Date:** 2026-10-10

## Context

When a case is escalated, the external customer portal must be told so it can inform the customer. Escalations happen inside triggers and batch jobs.

## Decision

Publish a `Case_Escalated__e` Platform Event (publish after commit) for every escalation. The portal subscribes to it through the Pub/Sub API.

## Alternatives considered

| Option                               | Why not                                                                                             |
| ------------------------------------ | --------------------------------------------------------------------------------------------------- |
| Synchronous callout from the trigger | Not allowed in triggers, and it would couple case saves to the portal's availability.               |
| `@future` or Queueable callout       | Works, but Salesforce must know the portal's endpoint, handle its retries and fail when it is down. |
| Outbound Messages                    | Legacy SOAP mechanism, limited to workflow-style automation.                                        |

## Consequences

- Salesforce does not depend on the portal being online; events are retained for replay.
- Publish-after-commit guarantees the portal never hears about an escalation that was rolled back.
- The portal must handle duplicate events idempotently, using the correlation id.
- Implemented in Phase 4.
