---
type: playbook
created: 2026-05-28
updated: 2026-05-28
related: [aws-infrastructure]
sources: [../sources/docs/2026-05-28-project-rules.md]
---

# Deployment

## When to use
Shipping railsstarter to staging or production, or configuring scheduled jobs / environment variables.

## Steps
- **Environment strategy:**
  - Development → local Docker Compose.
  - Staging → auto-deploy on merge to the `staging` branch.
  - Production → auto-deploy on merge to the `main` branch.
- **Local staging deploy (build images, push to ECR, update ECS):**
  ```bash
  bin/deploy-staging --profile railsstarter-staging   # full build, push, update ECS
  bin/deploy-staging --service web --no-deploy         # build + push web image only
  bin/deploy-staging --dry-run                         # preview commands
  ```
- **Scheduled jobs:** configure in `config/recurring.yml`. Current jobs: heartbeat (every 30s),
  CloudWatch metrics publishing (every minute).
- **Environment variables (sensitive):** add via AWS SSM, access in app as `ENV['_MY_VARIABLE']`:
  ```bash
  aws ssm put-parameter --name "/app/my_variable" --value "secret" --type "SecureString" \
    --region "us-east-1" --profile railsstarter-staging
  ```

## Verification
- ECS web/worker services pick up the new task definition after a deploy.
- `aws logs tail <log-group> --follow` shows the deployed revision running.

## Pitfalls
- Merging to `main` deploys to **production** automatically; merging to `staging` deploys to staging.
- OpenTelemetry tracing runs in staging/production only — don't expect traces locally. See
  [aws-infrastructure](../architecture/aws-infrastructure.md).

<!-- Source: ../sources/docs/2026-05-28-project-rules.md -->
