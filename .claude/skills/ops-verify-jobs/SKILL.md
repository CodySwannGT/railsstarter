---
name: ops-verify-jobs
description: "Verify that Solid Queue background jobs are running properly. Checks worker health, recurring job execution, and optionally triggers a test job to prove end-to-end processing. Supports local, staging, and production targets."
allowed-tools: ["Bash", "Read"]
---

# Verify Background Jobs

Verify that Solid Queue background jobs are running and processing correctly in the specified environment.

**Target environment**: `$ARGUMENTS` (expected: `local`, `staging`, or `production`; default: `staging`)

## Workflow

### Step 1: Set Environment Variables

| Environment | Profile | Cluster | Worker Service | Worker Log Group |
|---|---|---|---|---|
| local | — | — | `worker` (Docker) | Docker Compose logs |
| staging | `railsstarter-staging` | `webCluster` | `worker-service` | Discover via `aws logs describe-log-groups` |
| production | `railsstarter-production` | `webCluster` | `worker-service` | Discover via `aws logs describe-log-groups` |

### Step 2: Check Worker Service Health

#### If local

```bash
docker compose ps worker
```

Confirm the worker container is running and healthy.

#### If staging or production

1. **Check AWS session**:
   ```bash
   aws sts get-caller-identity --profile <profile>
   ```
   If expired: `aws sso login --profile <profile>`

2. **Check ECS service status**:
   ```bash
   aws ecs describe-services \
     --cluster webCluster \
     --services worker-service \
     --profile <profile> \
     --region us-east-1 \
     --query 'services[].{name:serviceName,status:status,running:runningCount,desired:desiredCount,rollout:deployments[0].rolloutState}' \
     --output table
   ```

   Verify: `running >= 1`, `status = ACTIVE`, `rollout = COMPLETED`.

### Step 3: Verify Recurring Jobs Are Executing

#### If local

```bash
docker compose logs --tail=100 worker 2>&1 | grep -E "(heartbeat|PublishCloudWatchMetrics|SolidQueue::RecurringJob)"
```

#### If staging or production

1. **Discover log groups**:
   ```bash
   aws logs describe-log-groups \
     --profile <profile> \
     --region us-east-1 \
     --query 'logGroups[].logGroupName' \
     --output table
   ```

2. **Search for recurring job execution** in the worker log group (last 15 minutes):
   ```bash
   aws logs filter-log-events \
     --log-group-name <worker-log-group> \
     --filter-pattern "Performing" \
     --start-time $(date -v-15M +%s000) \
     --profile <profile> \
     --region us-east-1 \
     --query 'events[].message' \
     --output text
   ```

3. **Check for job failures**:
   ```bash
   aws logs filter-log-events \
     --log-group-name <worker-log-group> \
     --filter-pattern "?Failed ?\"Error performing\"" \
     --start-time $(date -v-15M +%s000) \
     --profile <profile> \
     --region us-east-1 \
     --query 'events[].message' \
     --output text
   ```

### Step 4: Trigger a Test Job (End-to-End Proof)

This step enqueues a `VerifyJobExecutionJob` with a unique marker, then searches worker logs for that marker to prove the full pipeline works: enqueue -> pickup -> execute -> log.

#### If local

```bash
MARKER="verify-$(openssl rand -hex 8)"
echo "Marker: $MARKER"

# Enqueue the job
docker compose run --rm web bin/rails runner "VerifyJobExecutionJob.perform_later('$MARKER')"

# Wait for the worker to process it
sleep 5

# Search for the marker in worker logs
docker compose logs --tail=50 worker 2>&1 | grep "$MARKER"
```

#### If staging or production

1. **Generate a unique marker**:
   ```bash
   MARKER="verify-$(openssl rand -hex 8)"
   echo "Marker: $MARKER"
   ```

2. **Get a running web task for ECS exec**:
   ```bash
   TASK_ARN=$(aws ecs list-tasks \
     --cluster webCluster \
     --service-name web-rails-service \
     --profile <profile> \
     --query 'taskArns[0]' \
     --output text)

   TASK_ID=$(echo "$TASK_ARN" | awk -F/ '{print $NF}')

   CONTAINER_NAME=$(aws ecs describe-tasks \
     --cluster webCluster \
     --tasks "$TASK_ID" \
     --profile <profile> \
     --query 'tasks[0].containers[?starts_with(name, `ecs-service-connect`) == `false`].name' \
     --output text | awk '{print $1}')
   ```

3. **Enqueue the test job via ECS exec**:
   ```bash
   aws ecs execute-command \
     --cluster webCluster \
     --task "$TASK_ID" \
     --container "$CONTAINER_NAME" \
     --interactive \
     --command "bin/rails runner \"VerifyJobExecutionJob.perform_later('$MARKER')\"" \
     --profile <profile>
   ```

4. **Wait for the worker to process it** (30 seconds should be more than enough):
   ```bash
   sleep 30
   ```

5. **Search worker logs for the marker**:
   ```bash
   aws logs filter-log-events \
     --log-group-name <worker-log-group> \
     --filter-pattern "$MARKER" \
     --start-time $(date -v-2M +%s000) \
     --profile <profile> \
     --region us-east-1 \
     --query 'events[].message' \
     --output text
   ```

6. **Evaluate result**:
   - If the marker appears with `status=completed`: **PASS** — jobs are being enqueued and processed end-to-end
   - If the marker does not appear: **FAIL** — the worker is not picking up new jobs. Check worker service health, logs for errors, and SolidQueue dispatcher status

### Step 5: Report Results

Summarize findings in a table:

| Check | Result |
|---|---|
| Worker service running | Yes/No (count, status) |
| Recurring jobs executing | Yes/No (list which ones, any gaps) |
| Job failures in last 15 min | Count (list if any) |
| Test job (end-to-end) | PASS/FAIL (marker, timing) |
| Non-job errors (OTEL, etc.) | Note any noise |

If any check fails, provide the specific error output and a recommended next step.

## Execution

Verify jobs now for the specified environment.
