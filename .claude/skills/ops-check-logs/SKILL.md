---
name: ops-check-logs
description: "Check application logs from local Docker Compose or remote AWS CloudWatch environments. Supports local, staging, and production targets."
allowed-tools: ["Bash", "Read"]
---

# Check Application Logs

Check logs for the Railsstarter Rails application in the specified environment.

**Target environment**: `$ARGUMENTS` (expected: `local`, `staging`, or `production`)

## Workflow

### If target is `local`

1. **Verify Docker is running**:
   ```bash
   docker compose ps
   ```

2. **Tail recent logs from web and worker**:
   ```bash
   docker compose logs --tail=50 web
   docker compose logs --tail=50 worker
   ```

3. **If the user needs file-based logs**, read `log/development.log`

4. **Summarize** any errors, warnings, or notable output

### If target is `staging` or `production`

1. **Set the AWS profile**:
   - Staging: `railsstarter-staging`
   - Production: `railsstarter-production`

2. **Check AWS session**:
   ```bash
   aws sts get-caller-identity --profile <profile>
   ```
   If expired, run: `aws sso login --profile <profile>`

3. **Discover log groups**:
   ```bash
   aws logs describe-log-groups \
     --profile <profile> \
     --region us-east-1 \
     --query 'logGroups[].logGroupName' \
     --output table
   ```

4. **Tail recent logs** (last 10 minutes by default):
   ```bash
   aws logs tail <log-group> \
     --since 10m \
     --profile <profile> \
     --region us-east-1
   ```

5. **Filter for errors** if requested:
   ```bash
   aws logs filter-log-events \
     --log-group-name <log-group> \
     --filter-pattern "ERROR" \
     --start-time $(date -v-30M +%s000) \
     --profile <profile> \
     --region us-east-1 \
     --query 'events[].message' \
     --output text
   ```

6. **Summarize** findings: error counts, notable patterns, and recommended actions

## Execution

Check logs now for the specified environment.
