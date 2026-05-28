---
type: architecture
created: 2026-05-28
updated: 2026-05-28
related: [rails-8-modern-stack, deployment]
sources: [../sources/docs/2026-05-28-project-rules.md]
---

# AWS Infrastructure

## Overview
railsstarter runs on AWS, deployed to ECS Fargate with configuration and secrets managed through SSM
and Secrets Manager, and observability through CloudWatch and OpenTelemetry.

## Components
- **ECS Fargate** — production deployment with separate web and worker containers.
- **CloudWatch** — metrics publishing and logging (see `CloudWatchService` /
  `PublishCloudWatchMetricsJob` in [rails-8-modern-stack](rails-8-modern-stack.md)).
- **SSM Parameter Store** — environment-variable management; parameters are surfaced to the app
  `_`-prefixed (access as `ENV['_MY_VARIABLE']`).
- **Secrets Manager** — sensitive data storage.
- **OpenTelemetry** — distributed tracing, enabled in staging/production only.

## Data flow
- Config/secrets resolve from SSM + Secrets Manager into the container environment.
- Queue metrics are published to CloudWatch every minute by the recurring job.

## Constraints & decisions
- Add sensitive variables via `aws ssm put-parameter --type SecureString` (see
  [deployment](../playbooks/deployment.md) and [local-development](../playbooks/local-development.md)
  for the concrete commands).
- Tracing is intentionally off in development.

<!-- Source: ../sources/docs/2026-05-28-project-rules.md -->
