# 0006. Use a layered Apex architecture with a lightweight trigger framework

- **Status:** Accepted
- **Date:** 2026-10-11

## Context

Routing, SLA and escalation logic all run when cases change. Putting that logic directly in triggers makes it impossible to test in isolation, hard to order, and easy to break with a second trigger on the same object.

## Decision

Apex code is split into layers, each with one job:

| Layer    | Responsibility                                                   | Example              |
| -------- | ---------------------------------------------------------------- | -------------------- |
| Trigger  | One per object. No logic: delegates to its handler.              | `CaseTrigger`        |
| Handler  | Maps trigger events to service calls.                            | `CaseTriggerHandler` |
| Service  | Orchestrates a use case: reads data, applies rules, sets values. | `CaseRoutingService` |
| Domain   | Pure business rules, no SOQL or DML, unit-tested in memory.      | `CaseRouter`         |
| Selector | The only place that queries a given object.                      | `QueueSelector`      |

Handlers extend a small in-house `TriggerHandler` base class that dispatches on `Trigger.operationType` and supports bypassing a handler (for data loads and tests).

## Alternatives considered

| Option                                       | Why not                                                                                                                                                                                    |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Logic inside triggers                        | Untestable in isolation, no control over order, duplicated queries.                                                                                                                        |
| fflib Apex Common (Apex Enterprise Patterns) | The industry reference for this layering, but a large dependency for a project of this size. The layers here follow the same ideas, so moving to fflib later is a refactor, not a rewrite. |
| Record-triggered Flows                       | Good for simple field updates, weak for bulk logic that must be unit tested.                                                                                                               |

## Consequences

- Domain classes are tested with in-memory records: fast, no DML, every edge case covered.
- Services are tested end to end through the trigger, including a 200-record bulk insert.
- Every query lives in a selector, so query reuse and field lists stay consistent.
- Trigger automation runs in system mode: services use `inherited sharing`, and routing reads account tiers the creating user may not see.
