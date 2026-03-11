# Project Rules

Project-specific rules and guidelines that apply to this codebase.

Rules in `.claude/rules/` are automatically loaded by Claude Code at session start.
Add project-specific patterns, conventions, and requirements below.

---

## Local Development

### Setup

```bash
# Initial setup
cp env.sample .env
docker compose up --build

# Access app at http://localhost:3000
```

### Rails Commands (via Docker)

```bash
# General Rails commands
docker compose run web bin/rails <command>

# Database operations
docker compose run web bin/rails db:create
docker compose run web bin/rails db:migrate
docker compose run web bin/rails db:seed

# Console access
docker compose run web bin/rails console

# Testing
docker compose run web bin/rails test
docker compose run web bin/rails test:system

# Stop services
docker compose down
```

### Ruby Version (mise)

This project uses Ruby 3.4.8 managed by [mise](https://mise.jdx.dev/). The system Ruby (2.6.10 on macOS) will **not** work. Always activate mise before running any host-side Ruby/Rails/Bundler command:

```bash
eval "$(mise activate bash)"
```

Without this, you'll get `Your Ruby version is 2.6.10, but your Gemfile specified 3.4.8 (Bundler::RubyVersionMismatch)`.

### Pre-push Hooks (MySQL Required)

The `lefthook.yml` pre-push hooks run `bundle exec rspec` and `bundle exec brakeman` directly on the host (not inside Docker). Since rspec needs MySQL, you must have the database container running before pushing:

```bash
# Activate mise for correct Ruby version
eval "$(mise activate bash)"

# Start MySQL (runs at localhost:3306, accessible from host via TCP)
docker compose up -d db

# First time only: create and migrate test databases
PRIMARY_DB_HOST=127.0.0.1 bin/rails db:prepare RAILS_ENV=test
```

**Important:** Use `PRIMARY_DB_HOST=127.0.0.1` (not `localhost`) when running Rails commands on the host against Docker MySQL. The MySQL client interprets `localhost` as "use Unix socket" (`/tmp/mysql.sock`), which Docker doesn't expose. `127.0.0.1` forces TCP, which Docker does expose via `ports: ["3306:3306"]`.

There is no dotenv gem, so the `.env` file (with `PRIMARY_DB_HOST=db`) is only loaded by Docker Compose. Host-side commands use `database.yml` defaults (`localhost`) unless overridden.

### Auto-Generated Schema Files

Running `db:migrate` regenerates `db/schema.rb`, `db/cable_schema.rb`, `db/cache_schema.rb`, and `db/queue_schema.rb`. These files use double-quoted strings and lack `frozen_string_literal` comments, which triggers RuboCop violations. Always fix these violations before committing — never leave them broken or skip them. Run `bundle exec rubocop -A` on the changed schema files after any migration.

**Important:** Auto-generated schema files may have outdated `ActiveRecord::Schema` version numbers (e.g., 7.2 or 8.0 instead of 8.1). Always verify and update them to match the current Rails version.

### Multi-Database Commands

This app uses multiple databases (primary, queue, cache, cable). When running database commands on the host, always namespace the task for the specific database:

```bash
# Wrong - fails in multi-database apps
bin/rails db:migrate:down VERSION=20250212000000

# Correct - specify the database
bin/rails db:migrate:down:primary VERSION=20250212000000
```

### Code Quality

All host-side commands require `eval "$(mise activate bash)"` first.

```bash
# RuboCop (configured via Lefthook git hooks)
bundle exec rubocop

# Security scanning
bundle exec brakeman

# Run all pre-commit hooks manually
bundle exec lefthook run pre-commit
```

### Remote Environment Access

```bash
# Connect to remote console (staging)
aws sso login --profile railsstarter-staging
bin/remote-console railsstarter-staging

# Tail CloudWatch logs
aws logs tail <log-group> --follow --profile railsstarter-staging
```

## Architecture

### Rails 8 Modern Stack

- **Database**: Multi-database MySQL setup (primary, replica, queue, cache, cable)
- **Jobs**: Solid Queue (database-backed, no Redis required)
- **Cache**: Solid Cache (database-backed)
- **WebSockets**: Solid Cable (database-backed)
- **Assets**: Propshaft pipeline with Importmap for JavaScript
- **Frontend**: Hotwire (Turbo + Stimulus) for SPA-like behavior

### Key Application Components

**Controllers**: Basic web interface (`app/controllers/`)
- `HomeController` - Main landing page

**Background Jobs** (`app/jobs/`):
- `PublishCloudWatchMetricsJob` - Publishes queue metrics to AWS CloudWatch
- Scheduled via `config/recurring.yml` (every minute)

**Services** (`app/services/`):
- `CloudWatchService` - AWS CloudWatch integration for metrics publishing

### Multi-Database Configuration

The app uses separate databases for different concerns:
- **Primary**: Main application data
- **Queue**: Solid Queue job storage
- **Cache**: Solid Cache storage
- **Cable**: Solid Cable WebSocket connections
- **Replica**: Read-only database replica (when configured)

### AWS Integration

- **CloudWatch**: Metrics publishing and logging
- **SSM Parameter Store**: Environment variable management (prefixed with `_`)
- **Secrets Manager**: Sensitive data storage
- **ECS Fargate**: Production deployment with separate web/worker containers
- **OpenTelemetry**: Distributed tracing (staging/production only)

## Deployment

### Environment Strategy

- **Development**: Local Docker Compose
- **Staging**: Auto-deploy on merge to `staging` branch
- **Production**: Auto-deploy on merge to `main` branch

### Local Staging Deploy

Build Docker images locally and push to ECR, then update ECS services:

```bash
# Full deploy (build, push, update ECS)
bin/deploy-staging --profile railsstarter-staging

# Build and push only the web image
bin/deploy-staging --service web --no-deploy

# Preview commands without executing
bin/deploy-staging --dry-run
```

### Scheduled Jobs

Configure recurring jobs in `config/recurring.yml`. Current jobs:
- Heartbeat (every 30s)
- CloudWatch metrics publishing (every minute)

## Environment Variables

Add sensitive variables via AWS SSM:

```bash
aws ssm put-parameter --name "/app/my_variable" --value "secret" --type "SecureString" --region "us-east-1" --profile railsstarter-staging
```

Access in app as: `ENV['_MY_VARIABLE']`

## Code Quality Rules

Never modify `.reek.yml` to suppress or disable reek detectors without explicit human approval. Fix the underlying code smells instead.
