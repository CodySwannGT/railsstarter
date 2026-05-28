---
type: source
created: 2026-05-28
updated: 2026-05-28
related: []
sources: []
source_system: docs
original_file: .claude/rules/PROJECT_RULES.md
sensitivity: internal
---

# Source note — PROJECT_RULES.md (2026-05-28)

Ingested from `.claude/rules/PROJECT_RULES.md` (markdown, read directly). This is the project's
engineering handbook: local development, architecture, deployment, and code-quality conventions. The
original file remains in place (loaded by Claude Code at session start); this note is the sanitized,
citable snapshot for synthesis.

## Local development
- **Setup:** `cp env.sample .env` then `docker compose up --build`; app at `http://localhost:3000`.
- **Rails via Docker:** `docker compose run web bin/rails <command>` (db:create / db:migrate / db:seed,
  console, test, test:system); `docker compose down` to stop.
- **Ruby via mise:** Ruby 3.4.8 managed by mise. System Ruby (2.6.10 on macOS) will not work. Run
  `eval "$(mise activate bash)"` before any host-side Ruby/Rails/Bundler command, or you hit
  `Bundler::RubyVersionMismatch`.
- **Pre-push hooks (lefthook):** run `bundle exec rspec` and `bundle exec brakeman` on the host (not
  Docker). rspec needs MySQL, so start `docker compose up -d db` first; first time run
  `PRIMARY_DB_HOST=127.0.0.1 bin/rails db:prepare RAILS_ENV=test`.
- **`127.0.0.1` vs `localhost`:** host-side Rails commands against Docker MySQL must use
  `PRIMARY_DB_HOST=127.0.0.1` — the MySQL client treats `localhost` as a Unix socket
  (`/tmp/mysql.sock`), which Docker does not expose; `127.0.0.1` forces TCP (exposed via
  `ports: ["3306:3306"]`). There is no dotenv gem, so `.env` (`PRIMARY_DB_HOST=db`) is loaded only by
  Docker Compose; host commands fall back to `database.yml` defaults unless overridden.
- **Auto-generated schema files:** `db:migrate` regenerates `db/schema.rb`, `db/cable_schema.rb`,
  `db/cache_schema.rb`, `db/queue_schema.rb`. They use double-quoted strings and lack
  `frozen_string_literal`, tripping RuboCop — run `bundle exec rubocop -A` on them after a migration.
  Their `ActiveRecord::Schema` version may be stale (e.g. 7.2/8.0); update to the current Rails
  version (8.1).
- **Multi-database commands:** namespace per database, e.g. `bin/rails db:migrate:down:primary
  VERSION=...` (the un-namespaced form fails in multi-db apps).
- **Code quality:** `bundle exec rubocop`, `bundle exec brakeman`, `bundle exec lefthook run pre-commit`
  (all need mise activated first).
- **Remote access:** `aws sso login --profile railsstarter-staging` then
  `bin/remote-console railsstarter-staging`; `aws logs tail <log-group> --follow --profile
  railsstarter-staging` for CloudWatch.

## Architecture (Rails 8 modern stack)
- **Database:** multi-database MySQL — primary, replica, queue, cache, cable.
- **Jobs:** Solid Queue (database-backed, no Redis). **Cache:** Solid Cache. **WebSockets:** Solid
  Cable. **Assets:** Propshaft + Importmap. **Frontend:** Hotwire (Turbo + Stimulus).
- **Key components:** `HomeController` (landing page); `PublishCloudWatchMetricsJob` (publishes queue
  metrics to CloudWatch, scheduled via `config/recurring.yml` every minute); `CloudWatchService`
  (CloudWatch integration).
- **Multi-database roles:** primary (app data), queue (Solid Queue), cache (Solid Cache), cable (Solid
  Cable), replica (read-only, when configured).
- **AWS integration:** CloudWatch (metrics/logs), SSM Parameter Store (env vars, `_`-prefixed),
  Secrets Manager (sensitive data), ECS Fargate (prod, separate web/worker containers), OpenTelemetry
  (tracing, staging/production only).

## Deployment
- **Environment strategy:** development = local Docker Compose; staging = auto-deploy on merge to
  `staging`; production = auto-deploy on merge to `main`.
- **Local staging deploy:** `bin/deploy-staging --profile railsstarter-staging` (full build/push/update
  ECS); `--service web --no-deploy` (build+push web only); `--dry-run` (preview).
- **Scheduled jobs:** configured in `config/recurring.yml` — heartbeat (every 30s), CloudWatch metrics
  (every minute).
- **Environment variables:** add sensitive vars via AWS SSM (`aws ssm put-parameter --type
  SecureString …`); access in app as `ENV['_MY_VARIABLE']`.

## Code-quality rule
- Never modify `.reek.yml` to suppress/disable reek detectors without explicit human approval — fix the
  underlying code smell instead.
