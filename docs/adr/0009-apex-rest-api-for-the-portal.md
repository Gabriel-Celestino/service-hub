# 0009. Expose a purpose-built Apex REST API to the portal

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

The customer portal must create cases and show their SLA. Salesforce already offers generic REST endpoints for every object (`/sobjects/Case`, composite, SOQL queries), and the portal could call those directly.

## Decision

The portal talks to a small Apex REST API (`/portal/v1/cases`), documented in `docs/api/portal-api.yaml`:

- **Idempotent creation** on `externalId`, a unique External Id field on Case, so the portal can retry safely. A race between two identical requests is resolved by the unique index.
- **Validation in one place**, returning every invalid field at once in a stable error format.
- **Least privilege**: the integration user runs with the `Service_Hub_Integration` permission set only, and reads and writes run in user mode.
- **Traceability**: every call is logged in `Integration_Log__c` with an `X-Correlation-Id`, which the portal also logs.
- **Versioned URL** (`v1`), so the contract can evolve without breaking the portal.

## Alternatives considered

| Option                                   | Why not                                                                                                                                              |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Standard sObject REST API                | Couples the portal to the data model (field names, picklists, SOQL for the SLA milestones) and spreads validation between the portal and Salesforce. |
| Composite API with upsert by External Id | Gives idempotency, but still needs the portal to know the data model and returns no SLA view.                                                        |
| GraphQL API                              | Good for reads, but mutations still map one-to-one to objects.                                                                                       |

## Consequences

- The portal depends on a contract that we own and test, not on the object model.
- The API returns the SLA deadlines in the same response, so the portal needs one call per screen.
- Apex REST counts against the org's API limits like any other call; the portal caches nothing it does not need.
- A new major version (`v2`) is a new resource class, while `v1` keeps working.
