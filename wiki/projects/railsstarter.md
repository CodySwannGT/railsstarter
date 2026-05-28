---
type: project
created: 2026-05-28
updated: 2026-05-28
related: [rails-8-modern-stack]
sources: [../sources/git/2026-05-28-railsstarter-git.md, ../sources/docs/2026-05-28-project-rules.md]
---

# railsstarter

## Repository
| Field | Value |
|---|---|
| Remote | `CodySwannGT/railsstarter` |
| Default branch | `main` |
| HEAD at ingest | `03eb89c` |
| Commits (at ingest) | 40 |
| Latest merged PR | #47 — "chore: update @codyswann/lisa to 2.62.1" |

## Technology signals
Rails 8 application on the database-backed "Solid" stack (Solid Queue / Cache / Cable), multi-database
MySQL, Propshaft + Importmap assets, Hotwire frontend. Deployed to AWS ECS Fargate. See
[rails-8-modern-stack](../architecture/rails-8-modern-stack.md).

## Structure signals
- `app/controllers/` (`HomeController`), `app/jobs/` (`PublishCloudWatchMetricsJob`),
  `app/services/` (`CloudWatchService`).
- `config/recurring.yml` defines scheduled jobs (heartbeat, CloudWatch metrics).
- Tooling: Docker Compose for local dev, mise (Ruby 3.4.8), lefthook git hooks, RuboCop, Brakeman,
  reek.

## Notes & evidence
- History to date is dominated by `@codyswann/lisa` version bumps and template applications; the
  earliest commit `8395878` is "feat: initial railsstarter template" (2026-03-11) — this repo is a
  Rails starter template kept current with Lisa.

<!-- Sources: ../sources/git/2026-05-28-railsstarter-git.md, ../sources/docs/2026-05-28-project-rules.md -->
