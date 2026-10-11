# 0004. Store SLA deadlines as child records

- **Status:** Accepted
- **Date:** 2026-10-10

## Context

Each case has at least two deadlines, each with a target, an at-risk moment, a completion time, a status and pause tracking. They could be stored as fields on `Case` or as separate records.

## Decision

Each deadline is an `SLA_Milestone__c` record in a master-detail relationship with `Case`. A summary field, `Case.SLA_Status__c`, holds the worst status among open milestones for list views and reports.

## Alternatives considered

| Option                | Why not                                                                                                        |
| --------------------- | -------------------------------------------------------------------------------------------------------------- |
| Date fields on `Case` | About 12 fields for two deadlines, and every new deadline type means changing `Case`. No history per deadline. |

## Consequences

- New deadline types (for example, "next update") need only a new picklist value.
- Milestones can be reported on directly: met vs. breached by tier, by queue, by month.
- The escalation job queries milestones instead of cases, which keeps the query selective.
- Master-detail means milestones are deleted with their case and inherit its sharing.
