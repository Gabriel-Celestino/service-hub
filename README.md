# Service Hub

**An SLA-driven customer service platform on Salesforce, built with the practices of a software engineering team.**

[Leia em português](README.pt-BR.md)

Customers open cases through an external portal. Cases land in Salesforce, are routed to the right queue, are measured against an SLA, and are escalated automatically before the deadline is missed.

The goal is to show production-grade Salesforce engineering, not just configuration: a layered Apex architecture, real tests, CI/CD with scratch orgs, an external integration and documented architecture decisions.

> Project name is provisional.

![SLA Console: open cases ranked by urgency, with live countdowns](docs/images/sla-console.png)

_The SLA Console: cases ranked by urgency, with live countdowns and escalation levels._

## How it works

```mermaid
flowchart LR
    portal["Customer portal<br/>(Node.js + TypeScript)"] -- "REST + OAuth" --> sf
    subgraph sf["Salesforce"]
        direction TB
        routing["Routing engine"] --> sla["SLA engine"]
        sla --> esc["Escalation job"]
        console["Agent console (LWC)"]
    end
    esc -- "Platform Event" --> portal
    ai["AI classification"] -.-> routing
```

1. **Routing:** a new case is sent to a queue by rules stored in Custom Metadata (`Routing_Rule__mdt`).
2. **SLA:** each case gets two deadlines, first response and resolution, computed with Business Hours from the account tier and case priority (`SLA_Policy__mdt`). The clock pauses while the case is _Waiting on Customer_.
3. **Escalation:** a scheduled job flags milestones at risk (level 1) and breached (level 2), records an audit trail and notifies the portal.

## Roadmap

| Phase              | Scope                                                                                      | Status      |
| ------------------ | ------------------------------------------------------------------------------------------ | ----------- |
| 1. Foundation      | SFDX project, conventions, data model, ADRs                                                | Done        |
| 2. Domain          | Data model metadata, trigger framework, routing, SLA and escalation engines, 90%+ coverage | Done        |
| 3. Interface       | Agent console in LWC with Jest tests                                                       | In progress |
| 4. Integration     | Node.js + TypeScript portal, OAuth, Named Credentials, Platform Events                     | Planned     |
| 5. DevOps          | GitHub Actions with scratch orgs, static analysis, coverage badges                         | Planned     |
| 6. AI and showcase | AI case classification, final docs, demo video                                             | Planned     |

## Documentation

- [Data model](docs/data-model.md): objects, fields, configuration and SLA targets
- [Architecture Decision Records](docs/adr/README.md): why each design choice was made
- [Contributing](CONTRIBUTING.md): branches, commit convention and pull requests

## Getting started

**Prerequisites:** [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli), Node.js 20+, a Dev Hub org, and VS Code with the Salesforce Extension Pack.

```bash
# 1. Install dev tooling (Prettier, ESLint, Jest)
npm install

# 2. Authenticate to your Dev Hub (once)
sf org login web --set-default-dev-hub --alias devhub

# 3. Create a scratch org and deploy
sf org create scratch --definition-file config/project-scratch-def.json --alias service-hub --duration-days 30 --set-default
sf project deploy start

# 4. Grant access, schedule the escalation job and open the org
sf org assign permset --name Service_Hub_Agent
sf apex run --file scripts/apex/schedule-escalation.apex
sf org open

# 5. (Optional) Load demo data: accounts and cases in every SLA state
sf apex run --file scripts/apex/seed-demo-data.apex
```

## Using the app

Open the App Launcher and choose **Service Hub**.

- **SLA Console** tab: open cases ranked by urgency (breached, at risk, on track, paused), live countdowns, filters for _At risk & breached_ and _My queues_. Refreshes every minute.
- **Cases** tab: each case shows a live SLA panel with both deadlines and the escalation trail.

The scratch org allows deployments while Apex jobs are scheduled (`settings/Deployment.settings-meta.xml`), so the escalation job does not block deploys. In an org without that setting, run `scripts/apex/unschedule-escalation.apex` before deploying and reschedule afterwards.

## Project structure

```
force-app/main/default/
├── applications/        Service Hub Lightning app
├── classes/             Apex: trigger framework, services, domain, selectors, tests
├── customMetadata/      SLA policies and routing rules (records)
├── flexipages/          SLA Console page and Case record page
├── lwc/                 Lightning Web Components with Jest tests
├── objects/             Custom objects and fields on Account and Case
├── permissionsets/      Service_Hub_Agent
├── queues/              Support queues
├── settings/            Business Hours and deployment settings
├── standardValueSets/   Case Status, Priority and Origin values
├── tabs/                SLA Console tab
└── triggers/            One trigger per object
scripts/apex/            One-off Apex scripts (job scheduling, demo data)
config/                  Scratch org definition
docs/                    Data model and ADRs
```

## Tech stack

Salesforce Platform (Apex, LWC, Custom Metadata, Platform Events) · Salesforce CLI · Node.js + TypeScript · Jest · ESLint · Prettier · GitHub Actions
