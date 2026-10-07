# Local runtime

Copy `env.sample` to `.env` and run `docker compose up --build`. Development boot uses local configuration without AWS opt-in. See [AWS boot configuration](aws-bootstrap.md) for explicit remote loading.

Web and worker share `${COMPOSE_PROJECT_NAME}-app:local`, built from `Dockerfile.local` with pinned Ruby 3.4.11 and the same installed bundle. Web owns the build. Worker uses `pull_policy: never` to consume that local image without trying a registry pull before it exists. Start both services with `up --build` on a fresh machine. To start only the worker, first run `docker compose build web`. After changing the bundle, rebuild and recreate both services together:

```sh
docker compose up --build --force-recreate web worker
docker inspect --format '{{.Image}}' $(docker compose ps -q web worker)
docker compose exec web bundle check
docker compose exec worker bundle check
```

`worker.Dockerfile.local` is a compatibility symlink to the common Dockerfile for existing Ruby checks. Compose builds only `Dockerfile.local`.

The common image keeps `bin/docker-entrypoint` for jemalloc setup and command execution. The worker command executes `bin/worker-docker-entrypoint` then `bin/jobs`, preserving its existing job process.

Compose runs one `db-prepare` service with the same app image and environment. It waits for MySQL TCP health, then runs `./bin/rails db:prepare` for primary, queue, cache and cable. Web and worker start only after it exits successfully. TCP health avoids treating MySQL's temporary socket-only initialization server as ready.

If preparation fails, Compose reports the error and leaves both dependents unstarted. Inspect the preparation logs, correct the cause, and retry startup:

```sh
docker compose logs db-prepare
docker compose up --build web worker
```

Preparation is idempotent. After schema or bundle changes, recreate the preparation service with the application services:

```sh
docker compose up --build --force-recreate db-prepare web worker
```

The common entrypoint no longer prepares databases in each replica. Callers outside local Compose must arrange preparation before starting services. Production continues to use its dedicated migration task.

MySQL uses the official multi-platform image `mysql:8.4.11@sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242`. Check the running server with `docker compose exec db mysql -uroot -Nse 'SELECT VERSION();'`. Existing volumes persist across image changes. Consumers on another MySQL series must select and validate their own image, data upgrade path and matching CI input.

The committed Lisa quality CI inputs are `database_type: mysql` and `database_version: '8.4.11'`. The reusable workflow adds `mysql:`. The local Compose image uses the digest above; the CI caller selects the version tag. Fresh CI server/platform validation belongs to the shared CI change.
