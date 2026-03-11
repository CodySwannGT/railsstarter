---
name: ops-verify-telemetry
description: "Verify that OpenTelemetry traces are being collected and exported to X-Ray. Check trace health, find slow requests, investigate errors, and view service dependencies."
allowed-tools: ["Bash", "Read"]
---

# Verify OpenTelemetry Telemetry

Verify that OpenTelemetry traces are being collected and exported to AWS X-Ray in the specified environment.

**Target environment**: `$ARGUMENTS` (expected: `staging` or `production`; default: `staging`)

## Workflow

### Step 1: Set Environment Variables

| Environment | Profile |
|---|---|
| staging | `railsstarter-staging` |
| production | `railsstarter-production` |

### Step 2: Check AWS Session

```bash
aws sts get-caller-identity --profile <profile>
```

If expired: `aws sso login --profile <profile>`

### Step 3: Check Trace Health

Run the `health` subcommand to get trace count and sample traces from the last 5 minutes:

```bash
bin/verify-telemetry health <profile>
```

This confirms that the ADOT sidecar is receiving spans from the application and forwarding them to X-Ray.

### Step 4: Check Service Graph

Run the `services` subcommand to view the dependency map:

```bash
bin/verify-telemetry services <profile>
```

Verify that the `railsstarter-<env>` service appears in the graph and its downstream dependencies (MySQL, external APIs) are visible.

### Step 5: Investigate Issues (Optional)

Based on user request or anomalies found in previous steps:

**Slow requests (response time > 1s):**

```bash
bin/verify-telemetry slow <profile>
```

**5xx faults:**

```bash
bin/verify-telemetry errors <profile>
```

**Specific trace detail:**

```bash
bin/verify-telemetry trace <trace-id> <profile>
```

### Step 6: Report Results

Summarize findings in a table:

| Check | Result |
|---|---|
| AWS session active | Yes/No |
| Traces collected (last 5 min) | Count |
| Service graph populated | Yes/No (list services) |
| Slow requests (last hour) | Count |
| 5xx faults (last hour) | Count |

If any check fails, provide the specific error output and a recommended next step.

## Execution

Verify telemetry now for the specified environment.
