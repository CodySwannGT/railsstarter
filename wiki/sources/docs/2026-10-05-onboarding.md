---
type: source
created: 2026-10-05
updated: 2026-10-05
related: [wiki/playbooks/onboarding.md]
sources: [README.md]
sensitivity: internal
source_system: docs
original_filename: README.md
source_sha256: ab2befc45d8f94bb5deb8c69d25f6ea9df6b5957b28f6fac6f0a8690795711b7
source_base: fb07c214ed1151c01e1ec93a00bddc581dcd68e9
source_status: uncommitted-reviewed-provisional-draft
---
# Railsstarter onboarding facts from README

This targeted Markdown ingestion preserves selected reader-safe facts from the reviewed README draft. It is not a complete executable walkthrough. Scope: project identity, local database configuration, startup structure, generated ownership, branch policy and optional publication prerequisites. No command execution, adopted-package freshness or runtime success is asserted. The README's final commands may change and require a later meaningful ingestion.

## Project and tools

Railsstarter is a private Rails 8.1 application using MySQL, Solid Queue, Solid Cache, Solid Cable, Propshaft and Importmap. `main` is the only permanent integration branch. Rails environment names do not establish permanent dev/staging branches or automatic deployment.

Ruby is 3.4.11 in `.mise.toml`, `.ruby-version` and `Gemfile`. Host `mysql2` gems need compiler/client development libraries; container gems do not supply host hooks. Node/Bun engines, dependency manager, coherent lock and postinstall/template adoption must be reconciled against the accepted released Lisa package before publishing final install commands.

## Local configuration and four physical databases

The setting is `DATABASE_USER`. Compose reads a private `.env`; host Rails does not load it through dotenv. Container MySQL host is `db`; host Rails/tests/hooks use `127.0.0.1` and `DATABASE_PORT=3306`. `localhost` can select a Unix socket unavailable through Docker.

Compose binds MySQL to loopback port 3306 and web to port 3000. `COMPOSE_PROJECT_NAME` isolates names/volumes, not those ports. Preserve foreign resources and use isolated resources/free ports.

For a SQL-safe base `D`:

| Concern | Development database | Test database |
|---|---|---|
| Primary | `D` | `D_test` |
| Queue | `D_queue` | `D_queue_test` |
| Cache | `D_cache` | `D_cache_test` |
| Cable | `D_cable` | `D_cable_test` |

The local replica shares the primary identity; it is not a fifth physical database. Adapter is `mysql2`, Compose pins MySQL 8.4.11 by digest, encoding/collation are `utf8mb4`/`utf8mb4_0900_ai_ci`. A chosen user's grants and all four development/test schemas still need fresh-consumer proof. Private passwords/keys stay out of source and logs.

## Startup and hooks

Web, worker and one-shot `db-prepare` share the application image. Preparation waits for healthy MySQL, and application services depend on successful preparation. Entry points do not independently migrate. The reviewed source's `bin/setup --skip-server` checks/installs Ruby gems, prepares databases and clears logs/temp files; it does not rename, install Node dependencies/hooks or start a worker. This snapshot must be refreshed when accepted setup code changes.

Worker runs `bin/jobs`. Disabling AWS bootstrap does not disable the scheduled CloudWatch SDK call. An approved offline route and synthetic-job completion remain pending; process health alone does not prove recurring-job consumption.

Lefthook merges `lefthook.yml` and `lefthook-local.yml` and needs the host development bundle and test databases. Respect existing hook paths/foreign hooks. Real work-item checks require canonical binding and applicable item/trailer/provider gates; a conventional headline or executable hook file is insufficient proof. Final adopted install and positive/negative hook commands remain pending.

## Rename and generated ownership

Choose and reconcile Ruby module, public display/PWA name, package/repository slug, actual GitHub/Lisa/wiki identity, database base and isolated Compose project. Review corresponding references and every retained optional value. The README has an explicit placeholder map; it does not supply an automatic rename command in this revision. Optional AWS/Kamal/storage/mail/telemetry/profile values must be explicitly chosen or retained as inactive examples, not filled with invented infrastructure or business features.

Rails owns primary/queue/cache/cable generated schemas. Use native preparation/migration/dump tasks; dumps depend on task/database/environment and staging/production disable post-migration dumping. Do not manually force schema class versions/headers or blanket-autocorrect generated output. No rule that every migration dumps every schema is asserted.

## Optional AWS, assets and deployment

Local onboarding does not require deployment/publication credentials. `AwsBootstrap` executes before environment/database configuration: development/test default off, staging/production default on, explicit enablement and existing ENV precedence govern paginated SSM/export/secret lookup. SSM names relative to the configured path uppercase and replace slashes with underscores; no automatic leading underscore is added. Actual region, path, selectors, IAM, runtime database/key inputs and optional resources are supplied by the environment owner.

Image construction is credential-free; asset precompilation uses a dummy key without remote lookup. Separate `bin/publish-assets` requires Docker, AWS CLI, jq, a compiled immutable local web image and authorized S3 inputs. It extracts/validates assets from a created never-started container and syncs without deleting old fingerprints. `bin/deploy-staging` publishes before ECS update; its dry-run still authenticates/discovers AWS and no-deploy still builds/pushes. These are not read-only local probes.

## Pending acceptance

Final numbered setup/rename/dependency/worker commands, genuine common Lisa adoption, real hooks, complete placeholder coverage, two fresh renamed consumers, actual app/job/database/no-AWS evidence, Linux AMD64 proof and delivery remain pending with their owners. Factual ingestion does not complete onboarding or issue acceptance. Kernel synthesis follows this note, then index, append-only log, verification and only then state.

Source: README.md
