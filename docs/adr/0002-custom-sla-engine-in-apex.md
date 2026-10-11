# 0002. Build a custom SLA engine in Apex instead of Entitlements

- **Status:** Accepted
- **Date:** 2026-10-10

## Context

Every case has two deadlines: first response and resolution. Deadlines depend on the account tier and case priority, use Business Hours, pause while the case waits on the customer and trigger escalations.

Salesforce Service Cloud ships Entitlement Management (Entitlements, Entitlement Processes and Milestones), which covers much of this declaratively.

## Decision

Implement the SLA engine in Apex: milestones as `SLA_Milestone__c` records, targets in `SLA_Policy__mdt`, deadlines computed with `BusinessHours`, and a scheduled Batch Apex job for escalation.

## Alternatives considered

| Option                 | Why not                                                                                                                                                         |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Entitlement Management | Less code, but most logic would live in Setup configuration. This project's purpose is to demonstrate layered Apex design, testing and asynchronous processing. |
| Flow-only automation   | Hard to unit test, and time-based logic with pauses gets complex quickly in Flow.                                                                               |

## Consequences

- The engine is fully covered by Apex unit tests and versioned as code.
- We own edge cases that Entitlements already solve, such as pauses and recalculation after a priority change.
- In a real company already licensed for Service Cloud, Entitlement Management should be evaluated first; this ADR would be revisited there.
