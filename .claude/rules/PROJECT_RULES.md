# Project Rules

Use the [README checklist](../../README.md) with actual configuration. It describes the supported setup and disposable consumer validation routes. Source descriptions and documented commands are not runtime success claims.

## Local tools and configuration

Ruby is 3.4.11 in `.mise.toml`, `.ruby-version`, `Gemfile` and Dockerfiles. Use mise for host Ruby/Bundler, for example `mise exec ruby@3.4.11 -- ruby --version`. Resolve exact Node/Bun from the Lisa entry in committed `package-lock.json`, and Bundler from `Gemfile.lock`. Use Bun for project JavaScript dependencies. Setup uses a present Bun lock frozen and creates the initial lock when absent; do not prescribe a frozen install against an absent file or infer template adoption from postinstall success.

Use the real `DATABASE_USER`. Compose reads private `.env` with `PRIMARY_DB_HOST=db`; there is no dotenv gem to load it on the host. Host Rails/tests/hooks need explicit `PRIMARY_DB_HOST=127.0.0.1`, `DATABASE_PORT=3306` and matching consumer base/user. `localhost` can use a Unix socket unavailable through Docker. Private passwords/keys stay in resolver/input locations, never source, logs or task prompts.

Compose binds MySQL to `127.0.0.1:3306` and web to port 3000. `COMPOSE_PROJECT_NAME` isolates names/volumes, not ports. Use an isolated host or verified free ports; never reuse another actor's database/volume.

## MySQL and startup

Adapter `mysql2`; Compose pins MySQL 8.4.11 by digest. Encoding/collation are `utf8mb4`/`utf8mb4_0900_ai_ci`. For base `D`:

| Concern | Development | Test |
|---|---|---|
| Primary | `D` | `D_test` |
| Queue | `D_queue` | `D_queue_test` |
| Cache | `D_cache` | `D_cache_test` |
| Cable | `D_cable` | `D_cable_test` |

Local replica uses the primary database name, not a fifth physical database. Do not import PostgreSQL claims from a downstream wiki.

Web, worker and one-shot `db-prepare` share the application image; build through web before using the others. Preparation waits for healthy MySQL; both application services wait for successful preparation. Entry points execute their command without independent migrations.

`bin/setup --skip-server` requires a standalone checkout with its own `.git`, validates exact locked Ruby/Node/Bun/Bundler versions, installs JavaScript dependencies, checks/installs the development bundle, installs Lefthook, prepares development and test databases, and clears logs/temp files. It preserves dependency inputs and checks the installed Lisa identity without applying templates. Without that option it starts `bin/dev` (web only). It does not rename or start a worker. Never bypass its shared-hook or lifecycle refusal.

For installed host gems and isolated healthy MySQL, prepare tests with the consumer's TCP/base/user settings, for example:

```sh
DATABASE_NAME=acme_portal DATABASE_USER=root DATABASE_PORT=3306 \
  PRIMARY_DB_HOST=127.0.0.1 AWS_BOOTSTRAP_ENABLED=false RAILS_ENV=test \
  mise exec ruby@3.4.11 -- bin/rails db:prepare
```

Replace sample `acme_portal`/`root`; resolve private secrets separately. Root-default success does not prove that a chosen database user was configured. A non-root user needs real grants on every required development/test database.

## Hooks and quality

Host hooks require the development bundle/test databases, not just container gems. Respect existing `core.hooksPath` and foreign hooks. Read both `lefthook.yml` and `lefthook-local.yml`. Durable managed helper/hook/gem changes belong upstream in Lisa, not a manual copy or speculative apply.

Setup installs Lefthook. Work-item hooks require a real canonical binding, item/trailer and applicable provider gates; a conventional headline alone is not proof. Use the installed Lisa workflow to link the actual tracker item and attach the contribution branch, then ordinary Git commit/push invokes the original hooks and pre-push input. Do not bypass a missing gate or infer functionality from config/executable-file presence. The disposable smoke receipt hashes wrappers but does not execute these gates; functional hook verification uses the real contribution route.

Never modify `.reek.yml` to suppress or disable reek detectors without explicit human approval. Fix the underlying code smells instead.

## Native generated schemas

Rails owns `db/schema.rb`, `db/queue_schema.rb`, `db/cache_schema.rb`, `db/cable_schema.rb`. Use native preparation/migration/dump tasks and inspect diffs. Dumps depend on task/config; staging/production disable post-migration dumping. Do not claim every migration rewrites all four files, manually force class versions/headers or use blanket `rubocop -A` to rewrite native output. Resolve real lint/generator conflicts with the owner.

Use database-specific task names where required, such as `db:migrate:down:primary` for primary rollback. Confirm the task/version before destructive operations.

## AWS and worker boundaries

`AwsBootstrap` loads before environment/database configuration. Development/test default off; staging/production default on. Explicit true/false, existing ENV precedence and paginated SSM/exports/secret inventory govern lookup. `/app/my_variable` becomes `MY_VARIABLE`, with no automatic leading underscore. Missing database/key values need explicit unique secret selection and authorized environment-owned access. Keep errors/receipts sanitized.

Solid Queue/Cache/Cable are database-backed. Worker runs `bin/jobs`; recurring config declares heartbeat/CloudWatch schedules, but declarations/process health do not prove consumption. Bootstrap disabled does not disable the CloudWatch SDK call. `bin/smoke-consumer` validates two committed-source, renamed disposable consumers with test-only SDK tripwires, actual workers, synthetic-job completion, native schemas, named HTTP responses and owned cleanup. It uses ephemeral loopback ports and runs setup twice. Its test-only fixture is not an ordinary production configuration; normal workers need their selected scheduled integrations configured. Deployment credentials are not local acceptance prerequisites.

## Integration and optional deployment

`main` is the only permanent integration branch. Rails environment files do not create branch mappings or prove automatic deployment. Documentation/source findings do not establish hosted CI, release or deployed health.

Use the README's explicit placeholder map. Deployment/storage/telemetry examples are optional until chosen; owner supplies real profile/region, SSM path, selectors/exports, database/key values, IAM, ECR/ECS and bucket/CDN. Do not infer them from starter/inherited profiles, Kamal sample hosts/IPs or commented storage/mail examples. Do not make a new product-profile decision from this checklist.

Credential-free image construction, runtime configuration and asset publication are separate. `bin/publish-assets` extracts compiled assets from a created never-started immutable image and syncs without deleting old fingerprints; `bin/deploy-staging` publishes before ECS update. Its `--dry-run` authenticates/discovers AWS and `--no-deploy` builds/pushes. Neither is a read-only local probe.

## Wiki ownership

Query the installed wiki workflow first; empty synthesis permits source fallback, not runtime authority. Bootstrap/rendering belongs to the installed plugin, not an assumed consumer `scripts/ensure-wiki.mjs`. Kernel contracts are rendered from configuration. Ingestion order: sanitized source note, synthesis, index, log, verification, state, then commit/PR policy. No state advance before verification or hand-edited generated contract. Immutable historical source notes/cursors keep their original provenance when documentation changes; ingest the changed source separately. Wiki checks and independent fresh-consumer proof remain separate from source review.
