---
type: architecture
created: 2026-05-28
updated: 2026-05-28
related: [multi-database-mysql, aws-infrastructure]
sources: [../sources/docs/2026-05-28-project-rules.md]
---

# Rails 8 Modern Stack

## Overview
railsstarter is a Rails 8 application built on the "Solid" database-backed stack — no Redis required.

## Components
- **Database:** multi-database MySQL (primary, replica, queue, cache, cable). See
  [multi-database-mysql](multi-database-mysql.md).
- **Jobs:** Solid Queue (database-backed).
- **Cache:** Solid Cache (database-backed).
- **WebSockets:** Solid Cable (database-backed).
- **Assets:** Propshaft pipeline with Importmap for JavaScript.
- **Frontend:** Hotwire (Turbo + Stimulus) for SPA-like behavior.

## Key application components
- `HomeController` — main landing page (`app/controllers/`).
- `PublishCloudWatchMetricsJob` — publishes queue metrics to AWS CloudWatch (`app/jobs/`), scheduled
  via `config/recurring.yml` (every minute).
- `CloudWatchService` — AWS CloudWatch integration for metrics publishing (`app/services/`).

## Constraints & decisions
- Ruby 3.4.8, pinned via mise; the macOS system Ruby (2.6.10) is unsupported.
- Background jobs, cache, and websockets are all database-backed (Solid*), removing Redis as a
  dependency.

<!-- Source: ../sources/docs/2026-05-28-project-rules.md -->
