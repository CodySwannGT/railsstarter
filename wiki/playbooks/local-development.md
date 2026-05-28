---
type: playbook
created: 2026-05-28
updated: 2026-05-28
related: [multi-database-mysql]
sources: [../sources/docs/2026-05-28-project-rules.md]
---

# Local Development

## When to use
Setting up or working on railsstarter on a developer machine.

## Steps
1. **First-time setup:** `cp env.sample .env` then `docker compose up --build`. App at
   `http://localhost:3000`.
2. **Run Rails via Docker:** `docker compose run web bin/rails <command>` — e.g. `db:create`,
   `db:migrate`, `db:seed`, `console`, `test`, `test:system`. Stop with `docker compose down`.
3. **Activate Ruby (mise) for host-side commands:** `eval "$(mise activate bash)"` — Ruby is pinned to
   3.4.8; the macOS system Ruby (2.6.10) will not work (`Bundler::RubyVersionMismatch`).
4. **Before `git push` (lefthook pre-push runs rspec + brakeman on the host):**
   ```bash
   eval "$(mise activate bash)"
   docker compose up -d db                       # MySQL at localhost:3306 over TCP
   PRIMARY_DB_HOST=127.0.0.1 bin/rails db:prepare RAILS_ENV=test   # first time only
   ```
5. **Code quality (host, mise activated):** `bundle exec rubocop`, `bundle exec brakeman`,
   `bundle exec lefthook run pre-commit`.
6. **Remote console / logs (staging):**
   ```bash
   aws sso login --profile railsstarter-staging
   bin/remote-console railsstarter-staging
   aws logs tail <log-group> --follow --profile railsstarter-staging
   ```

## Verification
- App reachable at `http://localhost:3000`.
- `bin/rails test` / `test:system` pass inside Docker.
- pre-push hooks pass with the `db` container running.

## Pitfalls
- **`localhost` vs `127.0.0.1`:** host-side commands against Docker MySQL must use
  `PRIMARY_DB_HOST=127.0.0.1` (TCP); `localhost` resolves to a Unix socket Docker doesn't expose. See
  [multi-database-mysql](../architecture/multi-database-mysql.md).
- **No dotenv gem:** `.env` is read only by Docker Compose, not host commands.
- **After a migration:** run `bundle exec rubocop -A` on the regenerated `db/*_schema.rb` files and fix
  the `ActiveRecord::Schema` version if stale.
- **Multi-db commands** must be namespaced (`db:migrate:down:primary`).

<!-- Source: ../sources/docs/2026-05-28-project-rules.md -->
