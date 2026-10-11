# 0007. Escalate with a scheduled batch job instead of time-based automation

- **Status:** Accepted
- **Date:** 2026-10-11

## Context

Escalation depends on time passing, not on a record changing: a case nobody touches must still be flagged when its deadline approaches. Deadlines also move, because of pauses and priority changes.

## Decision

A Batch Apex job (`SlaEscalationBatch`), scheduled every 15 minutes, selects running milestones that are past their at-risk point or their target, refreshes their status and escalates their cases. Each level is escalated once, with an `Escalation__c` audit record.

## Alternatives considered

| Option                                         | Why not                                                                                                                                                               |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Record-triggered Flow with scheduled paths     | Paths are scheduled from a fixed field value; when a pause or priority change moves the deadline, every pending path must be cancelled and rescheduled. Hard to test. |
| Entitlement milestone actions                  | Tied to Entitlement Management, which ADR-0002 decided not to use.                                                                                                    |
| One scheduled job per case (`System.schedule`) | The org allows only 100 scheduled jobs.                                                                                                                               |

## Consequences

- Escalation happens up to 15 minutes after the at-risk or target time. That delay is acceptable for this domain and is configurable.
- The job is idempotent: running it twice at the same time escalates nothing new.
- The query only reads running milestones past a threshold, so it stays selective as data grows.
- Tests run the batch with an explicit evaluation time, so time-dependent behavior is deterministic.
