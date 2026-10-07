# Railsstarter

Rails 8.1 with MySQL, Solid Queue, Solid Cache, Solid Cable, Propshaft and Importmap. This is a private Rails application, not an npm publication target. `main` is the only permanent integration branch; Rails environment names do not establish permanent `dev`/`staging` branches or automatic deployment.

## Setup and rename

### 1. Choose an isolated checkout and identities

Clone the starter into a fresh standalone repository checkout and record `git rev-parse HEAD`. `bin/setup` requires that checkout's own `.git` directory; a linked worktree is refused to protect shared hooks. For a consumer, configure its actual Git remote and create its real GitHub repository separately. Setup does not create repositories or issues.

```sh
git clone https://github.com/CodySwannGT/railsstarter.git acme-portal
cd acme-portal
git rev-parse HEAD
```

Choose a Ruby constant, display name, package/repository slug and SQL-safe database base. The examples below use `AcmePortal`, `Acme Portal`, `acme-portal` and `acme_portal`; replace them with your identities. Keep the `SmokeConsumer` library namespace used by the disposable smoke runner unchanged.

Reserve ports 3000 and 3306 on an isolated development host. A distinct Compose project isolates images/volumes but does not change those fixed port bindings. Preserve other developers' checkouts, hooks, containers and databases.

### 2. Check prerequisites

Install mise, Docker with Compose, a compiler and MySQL client development headers/libraries for the host `mysql2` gem. Container gems do not supply host hooks. Ruby is 3.4.11 in `.mise.toml`, `.ruby-version` and `Gemfile`. Install it and check Docker:

```sh
mise install ruby@3.4.11
mise exec ruby@3.4.11 -- ruby --version
docker version
docker compose version
```

Docker needs a reachable daemon; Compose must support service health/completion dependencies. Read the required Node/Bun versions from the committed Lisa entry in `package-lock.json`, and Bundler from `Gemfile.lock`. The variables are reused below in the same shell:

```sh
NODE_VERSION=$(mise exec ruby@3.4.11 -- ruby -rjson -e 'puts JSON.parse(File.read("package-lock.json")).fetch("packages").fetch("node_modules/@codyswann/lisa").fetch("engines").fetch("node")')
BUN_VERSION=$(mise exec ruby@3.4.11 -- ruby -rjson -e 'puts JSON.parse(File.read("package-lock.json")).fetch("packages").fetch("node_modules/@codyswann/lisa").fetch("engines").fetch("bun")')
BUNDLER_VERSION=$(mise exec ruby@3.4.11 -- ruby -e 'puts File.read("Gemfile.lock").split("BUNDLED WITH\n").last.strip')
mise install "node@$NODE_VERSION" "bun@$BUN_VERSION"
mise exec ruby@3.4.11 -- gem install bundler --version "$BUNDLER_VERSION"
mise exec ruby@3.4.11 "node@$NODE_VERSION" "bun@$BUN_VERSION" -- bundle --version
```

Use Bun for project JavaScript dependencies. Lisa's package metadata declares Bun as the supported project installer. Do not run a frozen Bun install against an absent lock or change dependency versions just to satisfy setup.

### 3. Rename explicitly

Make explicit consumer edits, preserve behavior and review every remaining match. `bin/setup` does not rename the application. `bin/smoke-consumer` renames disposable validation copies, not your development checkout.

| Location / existing value | Replacement or optional treatment |
|---|---|
| `config/application.rb`: `module App`, project comment | Chosen Ruby constant/name. Search for corresponding `App::` references. |
| Home, layout title/navigation/footer and PWA: `Your Project` | Display name in `app/views/home/index.html.erb`, `app/views/layouts/application.html.erb`, `app/views/pwa/manifest.json.erb`. |
| `package.json` and lock root: `your-project` | Package slug, coherent with the adopted lock; do not change dependency resolutions to rename it. |
| Dockerfile image/container examples: `your-project` | Chosen image/container name when using those examples. Compose's local image name derives from `COMPOSE_PROJECT_NAME`. |
| `.lisa.config.json`: GitHub owner/repository | Actual consumer identity; starter is `CodySwannGT/railsstarter`. Keep tracker/source consistent. |
| `sonar-project.properties`: `your-org_your-project`, `your-org` | Actual Sonar project/organization when that optional analysis integration is configured. |
| Database `railsdb`; Compose fallback `railsstarter` | Private `DATABASE_NAME` and unique `COMPOSE_PROJECT_NAME`. Keep the consumer's host-owned `.github/workflows/ci.yml` database inputs consistent; Lisa seeds that caller on first setup and owns the reusable workflow it calls. |
| `wiki/lisa-wiki.config.json`: starter organization/display/purpose; any `your-org`/`your-project` template values | Actual consumer organization/display/purpose through supported wiki setup. Render the kernel-owned contract and orientation through the installed wiki workflow; never hand-edit the generated contract. |
| Sample `SECRET_KEY_BASE=secret_key_base` | Private local key; deployment uses its own resolved secret. Never print keys in documentation/logs. |
| AWS path, secret selectors, export names | Optional explicit environment-owned inputs described below. Local bootstrap stays disabled. |
| `your-project-staging`, log-group/trace examples | Optional real profile/resource inputs when using deployment, remote-console or verification tools. Review any inherited profile individually. |
| Kamal `your-project`, `your-user/your-project`, `your-user`, `192.168.0.1`/`.2`, `app.example.com`, `KAMAL_REGISTRY_PASSWORD`/`RAILS_MASTER_KEY` | Optional inactive deployment template. Resolve infrastructure/registry/key inputs before use. Commented MySQL 8.0/`DB_HOST` is not current MySQL 8.4/`PRIMARY_DB_HOST` setup. |
| Staging/production `example.com`, commented SMTP examples | Replace deployed mail-link host when used; configure inactive SMTP examples only when explicitly chosen. |
| `ALLOWED_HOSTS`, `CLOUDFRONT_ENDPOINT`, `REQUEST_INGRESS_PROFILE`, trusted proxy peer lists | Optional deployment inputs in `env.sample`. Production/staging need explicit host and ingress configuration. Choose the actual topology and trusted peers; no wildcard hosts or guessed proxy trust. Local web needs none of these deployment values. Rate-limit defaults (`REQUEST_RATE_LIMIT=120`, `REQUEST_RATE_PERIOD=60`, `REQUEST_RATE_LIMIT_ENABLED=true`) are active configuration, not identity placeholders. |
| `ACTIVE_STORAGE_STAGING_BUCKET`, `ACTIVE_STORAGE_PRODUCTION_BUCKET`, `ACTIVE_STORAGE_S3_REGION` | Ordinary staging/production uploads require their nonblank bucket and region. Credentials come from the runtime SDK/task role. These upload buckets are separate from compiled asset publication. Local/test storage is Disk. |
| Commented GCS/Azure `your_project`, `your_own_bucket`, `your_account_name`, `your_container_name`, `path/to/gcs.keyfile` | Optional disabled storage providers; configure only when selected. |
| `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`, `Your Project/BackgroundJobs` | Telemetry is optional. Enabling the exporter requires an explicit service name; choose the CloudWatch metric namespace in `app/jobs/publish_cloud_watch_metrics_job.rb` if that integration is used. |
| Optional AWS queue/export names such as `CensusQueueUrl` | Review integration values individually. They do not create a consumer business feature or change local Solid Queue's database backing. |
| `<command>`, `<question>`, source/URL/file/prompt/trace examples | Argument syntax: supply the intended command, question or source rather than treating it as an app setting. |

### 4. Configure private local inputs

Create `.env` only if absent:

```sh
test ! -e .env && (umask 077; cp env.sample .env)
```

Edit it privately: set the chosen `DATABASE_NAME`, actual `DATABASE_USER` setting, `DATABASE_PORT=3306`, `PRIMARY_DB_HOST=db`, unique `COMPOSE_PROJECT_NAME` and `AWS_BOOTSTRAP_ENABLED=false`. Replace the sample key. Empty-password root is only the isolated local Compose configuration, not a deployment credential policy.

Compose reads `.env`; host Rails does not. Export matching base/user and TCP settings separately. For an isolated sample using root and database base `acme_portal`:

```sh
export DATABASE_NAME=acme_portal DATABASE_USER=root DATABASE_PORT=3306
export PRIMARY_DB_HOST=127.0.0.1 AWS_BOOTSTRAP_ENABLED=false RAILS_ENV=development
export LOCAL_UID=$(id -u) LOCAL_GID=$(id -g)
```

The shared local image runs as your non-root UID/GID so it can traverse a private checkout and write its runtime files through the bind mount. Rebuild it after changing these values. Inside Compose use `db`; on the host use `127.0.0.1`/3306. `localhost` can select a Unix socket Docker does not expose. Resolve private passwords/keys separately without printing them or sourcing an arbitrary `.env` as shell code. A non-root `DATABASE_USER` must actually exist and have grants to create/use all development and test databases; changing `.env` does not create that user.

### 5. Install dependencies, hooks and databases

Start the isolated MySQL service before host setup:

```sh
docker compose pull db
docker compose up -d --wait db
mise exec ruby@3.4.11 "node@$NODE_VERSION" "bun@$BUN_VERSION" -- bin/setup --skip-server
```

`bin/setup` checks exact Ruby/Node/Bun/Bundler versions against the locks, installs JavaScript dependencies with Bun, checks/installs the development bundle, installs Lefthook, prepares all development and test databases, and clears logs/temp files. It uses an existing Bun lock frozen; without one it performs the initial install and requires the resulting lock. Keep that new lock with the consumer's dependency changes. Setup checks manifest/lock preservation and the installed Lisa identity. It installs dependencies without applying Lisa templates; template updates use the supported Lisa lifecycle separately. Without `--skip-server`, setup starts `bin/dev` (web only).

Lefthook uses the host development bundle and merges `lefthook.yml`/`lefthook-local.yml`. A standalone checkout protects other repositories' hook directories. Do not replace foreign hooks or bypass a setup refusal.

### 6. Start the named web application

Build the shared local image, run its one-shot preparation and start web:

```sh
docker compose build web
docker compose run --rm db-prepare
docker compose up -d web
curl --fail --silent --show-error http://127.0.0.1:3000/up
curl --fail --silent --show-error http://127.0.0.1:3000/
```

Compose pins MySQL 8.4.11 by digest. Web, worker and `db-prepare` share the local image. Preparation waits for healthy MySQL; both application services depend on its successful completion. Entry points do not independently migrate.

For database base `D`, four development databases are `D`, `D_queue`, `D_cache`, `D_cable`; tests use `D_test`, `D_queue_test`, `D_cache_test`, `D_cable_test`. The local replica shares the primary database identity, not a fifth physical database. Encoding/collation are `utf8mb4`/`utf8mb4_0900_ai_ci`.

Check that `/` displays your chosen name and `/up` returns success. `bin/jobs` is the worker command; the ordinary worker shares the same image and can be started with `docker compose up -d worker` when its scheduled integrations are configured. `AWS_BOOTSTRAP_ENABLED=false` disables bootstrap lookup, not the recurring CloudWatch SDK call. Use the isolated smoke route below to verify jobs without live AWS access.

### 7. Exercise two disposable consumers

From a checkout containing the committed source you want to validate, run:

```sh
docker compose pull db
mise exec ruby@3.4.11 "node@$NODE_VERSION" "bun@$BUN_VERSION" -- \
  bin/smoke-consumer --source HEAD --names acme_portal,acme_portal_two
```

The runner exports committed source only into two fresh standalone consumers, chooses loopback ports, runs setup twice per consumer and starts actual web/workers. It verifies renamed home/health responses, all four development and test schema identities, a consumed synthetic job and zero live AWS calls through its test-only SDK tripwire. It records private evidence under ignored `tmp/consumer-smoke/` and removes its owned runtime resources. It does not modify your development checkout, create provider repositories/issues, apply Lisa templates or exercise deployment. Names must be two distinct values matching `[a-z][a-z0-9_]{2,39}`. Optional `--repository OWNER/REPO` changes only the disposable consumers' declared identity; `--timeout SECONDS` bounds the whole run (default 1800, maximum 3600).

The smoke receipt checks executable Lefthook wrappers and their hashes. It does not execute the work-item/provider gates. Verify those through a real bound contribution as described below. Local smoke results also do not establish Linux AMD64 or hosted CI delivery.

### 8. Contribute through main

Lisa maps `main` to its terminal `production` lifecycle role so verified merges can complete their tickets. This is a tracker mapping; configure actual deployment separately for each generated application.

Use a short-lived feature branch targeting `main`. Choose a real issue in the consumer's configured tracker, and use the installed Lisa workflow to claim/link it and attach the branch. Inspect the binding with `node scripts/lisa-work-item.mjs current`; a copied binding or invented issue is invalid. Make an ordinary commit and push so the installed prepare/commit-message/pre-push hooks run with their actual arguments and push-ref input. Work-item trailers and applicable provider evidence are required in addition to a conventional headline. Host pre-push Rails checks need the prepared test databases and TCP settings from step 4.

For a documentation-only contribution, run its relevant local checks and normal hooks, then batch related changes into one PR. Preserve full CI on the assembled PR. Rails environment names do not require permanent `dev` or `staging` branches.

When finished with the local application, stop only its Compose project with `docker compose down`. Add `--volumes` only when you intend to delete that project's databases.

## Generated schemas

Rails owns `db/schema.rb` and the queue/cache/cable schema files. Use native database tasks and inspect output. Do not manually force `ActiveRecord::Schema` versions or rewrite generated files with blanket autocorrection. Dumps depend on task/database/environment; staging/production disable post-migration dumping. Resolve a real generator/lint conflict with its owner.

## Optional deployment prerequisites

Local onboarding needs no deployment credentials/publication. The environment owner supplies real profile/account/region, runtime database/key inputs, SSM path/IAM access, ECR repositories, ECS cluster/services/task families, asset bucket/CDN. Current scripts use `us-east-1` defaults; review those before selecting another region. The deploy helper discovers `webClusterName`, `webEcrRepositoryName`, `workerEcrRepositoryName` and a `ClientUploadBucket` export prefix; its optional service/task-family exports are `RailsServiceName`, `WorkerServiceName`, `RailsTaskFamily`, `WorkerTaskFamily`. Confirm actual values before using the helper.

`AwsBootstrap` runs before environment/database configuration. Development/test default to disabled; staging/production to enabled. Existing environment values win. Paginated/decrypted SSM relative names uppercase and replace slashes with underscores: `/app/my_variable` maps to `MY_VARIABLE`, not `_MY_VARIABLE`. Select the region through `AWS_REGION`/`AWS_DEFAULT_REGION` and SSM scope through `AWS_SSM_PATH`. Missing database/key values require explicit unique `AWS_DATABASE_SECRET_ID` or `AWS_DATABASE_SECRET_PREFIX`, and `AWS_SECRET_KEY_BASE_SECRET_ID` or `AWS_SECRET_KEY_BASE_SECRET_PREFIX`. Override exports through `AWS_EXPORT_<ENV_KEY>` where needed. The sole default export is `assetDomain`, mapped to `CLOUDFRONT_ENDPOINT`.

Image construction is credential-free; asset precompilation uses a dummy key without remote lookup. Separate `bin/publish-assets` needs Docker, AWS CLI, jq, a compiled local web image and authorized S3 bucket. It extracts/validates assets from a created never-started container and syncs without deleting old fingerprints. `bin/deploy-staging` publishes before ECS update. Its `--dry-run` still authenticates/discovers AWS; `--no-deploy` still builds/pushes. Neither is a local onboarding probe. Branch names alone do not trigger deployment.

## Project knowledge

Start at [wiki/start-here.md](wiki/start-here.md), the [onboarding playbook](wiki/playbooks/onboarding.md) and the [wiki contract](wiki/schema/llm-wiki-contract.md). Use the installed `$lisa-wiki-query`, `$lisa-wiki-ingest` and `$lisa-wiki-onboard-me` workflows. Wiki bootstrap/rendering belongs to the installed plugin, not an assumed consumer `scripts/ensure-wiki.mjs`. Change wiki identity through supported setup and configuration, then render the contract. Durable additions follow sanitized source note, synthesis, index, log, verification, state advancement, then commit/PR policy.
