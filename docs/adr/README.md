# Architecture Decision Records

Each significant design choice is recorded as an ADR: the context, the decision, what was rejected and the consequences. ADRs are never edited after they are accepted; a new ADR supersedes an old one.

| ADR                                                        | Decision                                                             | Status   |
| ---------------------------------------------------------- | -------------------------------------------------------------------- | -------- |
| [0001](0001-use-standard-case-object.md)                   | Use the standard Case object for tickets                             | Accepted |
| [0002](0002-custom-sla-engine-in-apex.md)                  | Build a custom SLA engine in Apex instead of Entitlements            | Accepted |
| [0003](0003-business-rules-in-custom-metadata.md)          | Keep business rules in Custom Metadata                               | Accepted |
| [0004](0004-sla-milestones-as-child-records.md)            | Store SLA deadlines as child records                                 | Accepted |
| [0005](0005-platform-events-for-outbound-notifications.md) | Notify external systems through Platform Events                      | Accepted |
| [0006](0006-layered-apex-architecture.md)                  | Use a layered Apex architecture with a lightweight trigger framework | Accepted |

New ADRs start from [the template](template.md).
