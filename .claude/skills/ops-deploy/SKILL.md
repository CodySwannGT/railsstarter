---
name: ops-deploy
description: "Deploy the Railsstarter Rails application to staging or production. Supports local builds via bin/deploy-staging and CI/CD via branch pushes."
allowed-tools: ["Bash", "Read"]
---

# Deploy Application

Deploy the Railsstarter Rails application to the specified environment.

**Target environment**: `$ARGUMENTS` (expected: `staging` or `production`)

## Workflow

### If target is `staging`

1. **Choose deployment method**:
   - **Local deploy** (build and push from workstation): `bin/deploy-staging`
   - **CI/CD deploy** (push to staging branch): merge/push to `staging` branch

2. **For local deploy**:
   - Verify prerequisites: Docker running, AWS CLI, jq, git installed
   - Check AWS session: `aws sts get-caller-identity --profile railsstarter-staging`
   - If expired: `aws sso login --profile railsstarter-staging`
   - Run the deploy:
     ```bash
     bin/deploy-staging --profile railsstarter-staging
     ```
   - Options: `--service web|worker` (default: all), `--no-deploy` (build/push only), `--dry-run` (preview)

3. **Post-deploy verification**:
   ```bash
   aws ecs describe-services \
     --cluster webCluster \
     --services web-rails-service worker-service \
     --profile railsstarter-staging \
     --region us-east-1 \
     --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount,rollout:deployments[0].rolloutState}' \
     --output table
   ```

4. **Check logs for errors** after services stabilize:
   ```bash
   aws logs describe-log-groups \
     --profile railsstarter-staging \
     --region us-east-1 \
     --query 'logGroups[].logGroupName' \
     --output table
   ```
   Then tail the relevant log group for recent errors.

### If target is `production`

1. **Require explicit confirmation** from the user before proceeding. Do NOT deploy to production without the user confirming they want to deploy.

2. **Important**: The production auto-deploy trigger (`main` branch) is currently **commented out** in `.github/workflows/deploy.yml`. Only the staging trigger is active.

3. **CI/CD deploy**: merge/push to `main` branch (if the trigger is re-enabled)

4. **Post-deploy verification** (same as staging but with `--profile railsstarter-production`)

## Execution

Deploy now to the specified environment.
