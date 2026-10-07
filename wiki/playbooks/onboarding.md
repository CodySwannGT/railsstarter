---
type: playbook
created: 2026-10-05
updated: 2026-10-06
related: [wiki/start-here.md]
sources: [wiki/sources/docs/2026-10-05-onboarding.md, wiki/sources/docs/2026-10-06-onboarding.md]
sensitivity: internal
---
# Railsstarter setup and contribution

Follow the numbered [README checklist](../../README.md) for commands and the complete replacement map. This playbook explains the configuration and ownership behind that flow. The earlier source note records the provisional draft; the 2026-10-06 note records updated source-supported instructions. Source review is separate from an independent command walkthrough and functional hook verification.

Source: wiki/sources/docs/2026-10-06-onboarding.md

## Application and integration

Railsstarter is a private Rails 8.1 application using MySQL, Solid Queue/Cache/Cable, Propshaft and Importmap. `main` is the only permanent integration branch. Environment names do not establish permanent dev/staging branches or prove automatic deployment. Ruby is 3.4.11; host MySQL gems/hooks need the development bundle and appropriate compiler/client libraries.

## Local database identity and TCP

Use actual `DATABASE_USER` and a SQL-safe `DATABASE_NAME` base. Compose reads private `.env`; host Rails does not load it through dotenv. Containers reach MySQL at `db`, while host Rails/tests/hooks require `127.0.0.1` and port 3306. `localhost` can select an unavailable Unix socket. Resolve passwords/keys privately without printing them or shell-sourcing arbitrary dotenv text.

Compose pins MySQL 8.4.11 by digest, with `utf8mb4` encoding and `utf8mb4_0900_ai_ci` collation. For base `D`:

| Concern | Development | Test |
|---|---|---|
| Primary | `D` | `D_test` |
| Queue | `D_queue` | `D_queue_test` |
| Cache | `D_cache` | `D_cache_test` |
| Cable | `D_cable` | `D_cable_test` |

The local replica shares the primary identity, not a fifth physical database. A chosen user's grants and native preparation of all four development and all four test databases need independent proof. Empty-password root in isolated Compose is not a deployment credential policy or evidence of another user's grants.

MySQL binds loopback port 3306 and web uses port 3000. Compose project names isolate names/volumes, not fixed ports. Use isolated resources/free ports and preserve other actors' databases, volumes and hooks.

Source: wiki/sources/docs/2026-10-05-onboarding.md

## Rename and optional values

Use a standalone clone with its own .git directory; setup refuses linked worktrees to protect shared hooks. Choose distinct Ruby/display/package/database identities and keep the validation runner's SmokeConsumer namespace unchanged. The README supplies the explicit placeholder map. Reconcile these groups without inventing infrastructure or consumer business features:

| Group | Owner / treatment |
|---|---|
| Ruby `App` module/references | Consumer chooses Ruby constant and reviews corresponding references. |
| Public display/home/layout/PWA | Consumer chooses display name. |
| Package slug and coherent lock root | Consumer renames identity; adopted dependency owner retains coherent resolution. |
| GitHub/Lisa repository identity | Actual consumer owner/repository and real work-item identity. |
| Sonar/image/container examples | Optional analysis identity and chosen names for deployment examples. |
| Database base and Compose project | Consumer chooses isolated identities and real user, and keeps its host-owned CI caller's database inputs consistent. The reusable workflow remains Lisa-owned. |
| Wiki organization/display/purpose | Config identity plus supported contract renderer and ordered ingest. |
| Sample application key | Replace privately; never write real key values to source or logs. |
| AWS scope/selectors/exports | Optional environment-owned inputs with authorized access. |
| Profiles/log groups/traces | Optional explicit real resource selection. |
| Kamal hosts/image/registry/key examples | Inactive deployment template until selected and configured. |
| Mail links/SMTP/allowed hosts | Optional actual deployed configuration when chosen. |
| Commented GCS/Azure settings | Optional disabled providers; local/test storage is Disk. |
| Active Storage deployed uploads | Explicit staging/production upload bucket and S3 region with runtime task-role credentials; separate from asset publication. |
| Telemetry service/metric names | Explicit consumer identity if telemetry is used. |
| Inherited styling/profile/queue integration values | Review individually; no global queue/business rename. |
| Documentation argument placeholders | Syntax requiring an intended argument, not an app setting. |

Review every remaining placeholder in the renamed source, including optional deployment and telemetry examples. Preserve dependency resolutions when changing package/lock root identity. Generate wiki identity/contract changes through the supported installed workflow.

## Native preparation and hooks

Derive exact Node/Bun from the committed Lisa lock entry and Bundler from Gemfile.lock. Use Bun for project JavaScript dependencies. After healthy MySQL starts, bin/setup --skip-server checks exact tools, installs JavaScript dependencies, checks/installs the development bundle, installs Lefthook, prepares development and test databases and clears logs/temp files. An existing Bun lock is frozen; an absent lock requires the initial install to create one. Setup checks preserved dependency inputs and installed Lisa identity without applying templates. It does not rename or start a worker. Without the flag, it starts bin/dev (web only).

Web, worker and one-shot preparation share an application image. Build web before using db-prepare or worker. Preparation waits for healthy MySQL; application services wait for successful preparation. Entry points do not run independent migrations.

Rails owns primary/queue/cache/cable generated schema files. Use native tasks and inspect output. Dumps vary by task/database/environment; staging/production disable post-migration dumping. Do not force schema class versions/headers, blanket-autocorrect native output or claim every migration dumps every schema.

Lefthook combines managed/local configuration and needs host gems/test databases. Respect foreign hooks and configured hook paths. Use a real tracker item and installed Lisa workflow to establish the canonical binding and contribution branch. Ordinary commit/push executes the hooks with original arguments/input and applicable trailer/provider gates. The smoke runner hashes installed wrappers but does not execute their gates. A conventional headline or installed file is insufficient functional proof.

Source: wiki/sources/docs/2026-10-06-onboarding.md

## AWS, worker and publication boundaries

Development/test bootstrap defaults off; staging/production defaults on. Bootstrap precedes environment/database configuration, honors existing ENV, and uses paginated SSM/export/secret lookup. Names relative to SSM scope uppercase and replace slashes with underscores without adding a leading underscore. Actual region/path/selectors and IAM are environment-owned.

Worker runs bin/jobs. Disabling bootstrap does not disable the scheduled CloudWatch SDK call; normal workers need their selected scheduled integrations configured. For isolated offline validation, bin/smoke-consumer --source HEAD --names acme_portal,acme_portal_two exports committed source into two disposable consumers, uses ephemeral loopback ports and runs setup twice. Actual workers consume a synthetic job, HTTP checks confirm renamed home/health responses, schema checks cover four development/test identities, and test-only SDK tripwires check zero live AWS calls. It records private evidence and cleans owned runtime resources. It does not rename the development checkout, create provider identities or deploy. Process health alone is not job-completion proof.

Image construction is credential-free and uses a dummy precompile key without remote lookup. Separate asset publication needs Docker/AWS CLI/jq, a compiled immutable local image and authorized S3 inputs. It extracts from a created never-started container and syncs without deleting old fingerprints. Deployment publishes assets before ECS update. Its dry-run still authenticates/discovers AWS and no-deploy still builds/pushes; neither is a read-only local probe. Local onboarding requires no deployment credentials.

Source: wiki/sources/docs/2026-10-06-onboarding.md

## Remaining proof and source freshness

A different actor must follow the final numbered commands in a fresh renamed consumer and retain named home/health responses, all four development/test database identities, installed and functional hooks, consumed jobs, no-live-AWS smoke evidence and owned cleanup. Functional provider gates require a real bound contribution and remain separate from the smoke wrapper receipt. Linux AMD64 and hosted delivery evidence also remain separate.

This source update does not certify runtime acceptance or complete issue #76. Supported wiki verification must pass before the docs cursor advances. The earlier cursor and immutable source note retain their historical provenance.
