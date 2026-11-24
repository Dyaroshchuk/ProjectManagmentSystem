# PMIMP — Project Management on Salesforce

[![CI](https://github.com/Dyaroshchuk/ProjectManagmentSystem/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/Dyaroshchuk/ProjectManagmentSystem/actions/workflows/ci.yml)

PMIMP is a Kanban project management app built natively on the Salesforce Platform.

- **Isolated workspaces** in one org: members see only the workspaces they belong to
  (Owner, Admin, Member, Viewer roles, enforced with Salesforce sharing).
- **Per-project workflows**: configurable statuses and allowed transitions, from
  starter templates (Simple, Software, Content).
- **Kanban board** on the Project record page with drag-and-drop and keyboard moves.
- **Work items with keys** like `PRJ-123`, one level of subtasks, soft delete.
- **Activity log** of every tracked change, written asynchronously via Platform Events.
- **API-first**: the LWC UI and the Apex REST API (`/v1/*`) share one service layer
  and return the same DTOs. Flow integration through invocable actions.

> **Status:** early development. The board (v0.1) is planned for February 2027 and
> the MVP for March 2027. See [Roadmap](#roadmap).

## Tech stack

Apex (lightweight Service / Domain / Selector layering, no external libraries) ·
Lightning Web Components · Platform Events · Custom Metadata · Apex REST ·
Salesforce CLI (`sf`) · GitHub Actions · Jest · Salesforce Code Analyzer.

Plain SFDX source — no managed package, no namespace.

## Getting started

### Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`) and
  the Code Analyzer plugin: `sf plugins install code-analyzer`
- Node.js LTS and npm
- A Dev Hub org (a free [Developer Edition](https://developer.salesforce.com/signup)
  with Dev Hub enabled under Setup → Dev Hub), authorized with
  `sf org login web --set-default-dev-hub --alias DevHub`

### Set up a scratch org

```bash
npm install
sf org create scratch -f config/project-scratch-def.json -a pmimp -d -y 7
sf project deploy start -o pmimp
npm run seed                      # demo users + sample data (rerunnable)
sf org open -o pmimp
```

### Develop and test

```bash
sf apex run test -o pmimp --test-level RunLocalTests --code-coverage --result-format human --wait 30
npm run test:unit                 # LWC Jest
npm run lint                      # ESLint for LWC
npm run prettier:verify           # formatting
npm run scan                      # Salesforce Code Analyzer
```

A pre-commit hook (Husky + lint-staged) formats staged files and runs related Jest tests.

## Scratch org and demo users

The scratch org is Developer edition (`config/project-scratch-def.json`). Platform
Events need no extra scratch org feature.

User licenses in a Developer-edition scratch org (measured 2026-11-24):

| License             | Total | Used by admin | Free |
| ------------------- | ----- | ------------- | ---- |
| Salesforce          | 2     | 1             | 1    |
| Salesforce Platform | 3     | 0             | 3    |

The scratch org admin plays the workspace **Owner**. `npm run seed` creates the
other demo users on the 4 free seats:

| Persona  | Username                                   | License             |
| -------- | ------------------------------------------ | ------------------- |
| Admin    | `pmimp.admin@<orgid>.pmimp.example.com`    | Salesforce Platform |
| Member   | `pmimp.member@<orgid>.pmimp.example.com`   | Salesforce Platform |
| Viewer   | `pmimp.viewer@<orgid>.pmimp.example.com`   | Salesforce Platform |
| Outsider | `pmimp.outsider@<orgid>.pmimp.example.com` | Salesforce          |

To log in as a demo user, set a password with
`sf org generate password -o pmimp --on-behalf-of <username>`, or use **Login** on
the user record in Setup.

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on pushes to `master` and
on pull requests:

1. Prettier, ESLint, LWC Jest, Code Analyzer (report uploaded as an artifact).
2. JWT login to the Dev Hub, a one-day scratch org, deploy, Apex tests; the scratch
   org is always deleted.

Required repository secrets: `SF_CLIENT_ID` (consumer key of the Dev Hub External
Client App), `SF_JWT_KEY` (private key matching the app's certificate) and
`SF_DEVHUB_USERNAME`.

## Project structure

```
force-app/main/default/
  classes/        Apex: framework, selectors, domain, services, sharing, async,
                  api (REST), controllers (LWC), invocable, tests
  triggers/       one logic-free trigger per object
  lwc/            Lightning Web Components (board, cards, modals, timeline)
  objects/  customMetadata/  permissionsets/  flows/  labels/
scripts/apex/     create-demo-users.apex, seed-data.apex
config/           scratch org definition
.github/          CI workflow
```

## Roadmap

| Milestone                                       | Target      |
| ----------------------------------------------- | ----------- |
| M0 Setup — repo, scratch org, CI, seed scripts  | Dec 2026    |
| M1 Foundation — data model, workspaces, sharing | Dec 2026    |
| M2 Projects, workflows, keys, work items        | Jan 2027    |
| M3 Kanban board (**v0.1**)                      | Feb 12 2027 |
| M4 Activity log and logging                     | Feb 2027    |
| M5 REST API and automation                      | Mar 2027    |
| M6 Hardening and showcase (**MVP**)             | Mar 26 2027 |

## Design documentation

The full design — HLD/LLD, ERD, UML diagrams and architecture decision records —
is maintained alongside the code and will be published with M6. Until then, this
README is the public overview.
