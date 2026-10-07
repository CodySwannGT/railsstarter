# Runtime dependency upgrades

This candidate refreshes compatible host gems and lock selections allowed by the already published Lisa constraints. Ruby 3.4.11, Rails 8.1.4 and already current direct gems are retained. The eight managed major upgrades are now selected in the committed lock through the published Lisa constraints. Their combined runtime and tooling validation belongs to #85.

## Direct inventory

| Gem | Frozen baseline | Candidate | Researched latest | Ownership |
| --- | --- | --- | --- | --- |
| aws-sdk-cloudformation | 1.149.0 | 1.159.0 | 1.159.0 | starter |
| aws-sdk-cloudwatch | 1.129.0 | 1.149.0 | 1.149.0 | starter |
| aws-sdk-s3 | 1.213.0 | 1.233.1 | 1.233.1 | starter |
| aws-sdk-secretsmanager | 1.128.0 | 1.136.0 | 1.136.0 | starter |
| aws-sdk-ssm | 1.210.0 | 1.223.0 | 1.223.0 | starter |
| bootsnap | 1.22.0 | 1.26.0 | 1.26.0 | starter |
| brakeman | 7.1.2 | 8.1.0 | 8.1.0 | Lisa |
| bullet | 8.1.0 | 8.2.0 | 8.2.0 | Lisa |
| bundler-audit | 0.9.3 | 0.9.3 | 0.9.3 | Lisa |
| capybara | 3.40.0 | 3.40.0 | 3.40.0 | starter |
| database_consistency | 1.7.27 | 3.0.14 | 3.0.14 | Lisa |
| debug | 1.11.1 | 1.11.1 | 1.11.1 | starter |
| factory_bot_rails | 6.5.1 | 6.5.1 | 6.5.1 | Lisa |
| faker | 3.6.0 | 3.8.0 | 3.8.0 | Lisa |
| flay | 2.14.2 | 2.14.4 | 2.14.4 | Lisa |
| flog | 4.9.4 | 4.9.4 | 4.9.4 | Lisa |
| importmap-rails | 2.2.3 | 2.2.3 | 2.2.3 | starter |
| jbuilder | 2.14.1 | 2.15.1 | 2.15.1 | starter |
| kamal | 2.10.1 | 2.12.0 | 2.12.0 | starter |
| lefthook | 2.1.1 | 2.1.16 | 2.1.16 | Lisa |
| mutant-rspec | 0.16.3 | 0.17.0 | 0.17.0 | Lisa |
| mysql2 | 0.5.7 | 0.5.7 | 0.5.7 | starter |
| mysql2-aws_rds_iam | 0.2.0 | 0.2.0 | 0.2.0 | starter |
| opentelemetry-exporter-otlp | 0.31.1 | 0.37.0 | 0.37.0 | starter |
| opentelemetry-instrumentation-all | 0.90.1 | 0.97.0 | 0.97.0 | starter |
| opentelemetry-sdk | 1.10.0 | 1.13.1 | 1.13.1 | starter |
| propshaft | 1.3.1 | 1.3.2 | 1.3.2 | starter |
| puma | 8.0.2 | 8.0.2 | 8.0.2 | starter |
| rack-attack | 6.8.0 | 6.8.0 | 6.8.0 | Lisa |
| rack-mini-profiler | 3.3.1 | 5.0.0 | 5.0.0 | Lisa |
| rails | 8.1.4 | 8.1.4 | 8.1.4 | starter |
| reek | 6.5.0 | 6.6.0 | 6.6.0 | Lisa |
| rspec-rails | 7.1.1 | 8.0.4 | 8.0.4 | Lisa |
| rubocop | 1.84.1 | 1.91.0 | 1.91.0 | Lisa |
| rubocop-capybara | 2.22.1 | 3.0.0 | 3.0.0 | Lisa |
| rubocop-factory_bot | 2.28.0 | 2.28.0 | 2.28.0 | Lisa |
| rubocop-performance | 1.26.1 | 1.27.0 | 1.27.0 | Lisa |
| rubocop-rails | 2.34.3 | 2.38.0 | 2.38.0 | Lisa |
| rubocop-rspec | 3.9.0 | 3.10.2 | 3.10.2 | Lisa |
| rubocop-yard | 0.10.0 | 1.3.0 | 1.3.0 | Lisa |
| selenium-webdriver | 4.40.0 | 4.50.0 | 4.50.0 | starter |
| shoulda-matchers | 6.5.0 | 8.0.1 | 8.0.1 | Lisa |
| simplecov | 0.22.0 | 1.3.2 | 1.3.2 | Lisa |
| solid_cable | 3.0.12 | 4.1.0 | 4.1.0 | starter |
| solid_cache | 1.0.10 | 1.0.10 | 1.0.10 | starter |
| solid_queue | 1.3.1 | 1.7.0 | 1.7.0 | starter |
| stimulus-rails | 1.3.4 | 1.3.4 | 1.3.4 | starter |
| strong_migrations | 2.5.2 | 2.8.0 | 2.8.0 | Lisa |
| thruster | 0.1.18-aarch64-linux, 0.1.18-arm64-darwin, 0.1.18-x86_64-linux | 0.1.26 | 0.1.26 | starter |
| turbo-rails | 2.0.23 | 2.0.23 | 2.0.23 | starter |
| tzinfo-data |  | platform conditional | 1.2026.5 | starter |
| vcr | 6.4.0 | 6.4.0 | 6.4.0 | Lisa |
| web-console | 4.2.1 | 4.3.0 | 4.3.0 | starter |
| webmock | 3.26.1 | 3.26.4 | 3.26.4 | Lisa |
| yard | 0.9.44 | 0.9.45 | 0.9.45 | Lisa |

Latest metadata was captured on 2026-10-05 from the official RubyGems APIs. It describes availability. The resolved lock is the candidate, and local checks describe local behavior. None of these establishes hosted Linux AMD64, publication, deployment or provider delivery.

## Upgrade route

The official Solid Queue 1.7 update generator produced `db/queue_migrate/20261005023123_add_batches_to_solid_queue.rb`. Its nullable jobs.batch_id, job index, batch tables and cascading foreign keys are additive. Host formatting and splitting the two table definitions into private methods preserve the generated operations. No application batching or fiber worker feature is added. The generated queue schema must come from the actual migration database readback, never by copying the installer schema over existing data.

Reviewed #77 donor fa37d6381ed20db37c26d7d89e6d15fc1e63602e was integrated through a normal fast-forward merge, preserving its original commit and all six source identities. Local migration readback uses Strong Migrations 2.8 with MySQL target 8.4, safe_by_default, and enabled add_index_columns. The preservation runner checks the actual settings and exact initializer bytes in committed HEAD before db:migrate:queue. The additive migration uses active checks and preserves existing rows. The failed attempt to couple ordinary test preparation to those witnesses is recorded below and excluded from preservation acceptance. Independent acceptance remains a separate judgment.

Solid Cable 3.0.12 to 4.1.0 is an explicit major transition. Existing binary channel/payload columns, signed channel hash and channel index are retained. No pre-v3 updater, encryption conversion or index removal is required. The fixture observes actual delivery, retained payload bytes, unsubscribe behavior, a pending writer flush during shutdown and an actual NOT NULL failure reported by the async writer. Stored messages are retained data and are not a promise of historical replay.

The standalone transition seeds recent cable/cache values and ready, scheduled and failed jobs with the old installed bundle, then checks the same authenticated server UUID and physical schemas after switching bundle. Migration applies only through db:migrate:queue. Normal rspec uses its own fresh resources and never depends on a private builder receipt or the old-bundle installation. The seed also creates blocked jobs through the actual concurrency adapter and a claimed job through its claim API, retaining the semaphore and owner rows. The upgraded runtime reads these states before the owner API releases its claim, then observes independent job effects. The existing recurring fixture retains all five genuine scheduler/queue/error controls and uses an owned YAML schedule file for the new path-validation callback. Local migration readback preserved those states before the new workers consumed the eligible jobs. The queue schema is the actual migrated database dump, with only host formatting applied.

## Local checks

Use Ruby 3.4.11, Bundler 2.4.10, installed Node, Python 3, Docker through a local Unix socket and the installed MySQL 8.4.11 image at `sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242`. An installed compatible Chrome and chromedriver are required. Set CHROMEDRIVER to the installed executable to avoid a driver download. Existing workflow tests also require the documented installed Lisa checker at node_modules/@codyswann/lisa/scripts/check-third-party-action-pins.mjs with its two local imports. That prerequisite is distinct from adopting the host package manifest or the managed major ranges.

```sh
bundle check
python3 test/runtime/dependency_upgrade/runner.py
python3 test/runtime/dependency_upgrade/runner.py --development
python3 bin/test-recurring-worker
bundle exec rspec
bundle exec rubocop
bundle exec reek app/ lib/
bundle exec brakeman --no-pager
bundle exec bundler-audit check --update
```

For the old-to-new transition, install the exact frozen baseline Gemfile/lock into a separate bundle path. Its directory must contain the four frozen db/schema files. Keep that cache and source immutable, then use the upgraded bundle to run:

```sh
python3 test/runtime/dependency_upgrade/runner.py \
  --baseline-gemfile /absolute/frozen-baseline/Gemfile \
  --baseline-bundle-path /absolute/old-installed-bundle
```

The runner provisions a unique loopback MySQL endpoint and four synthetic schemas with restricted grants, validates all rendered roles including the hidden replica before app access, rejects unsafe URL/host/port/credential routes, and removes only its positively identified container, volume and child processes. Every result including failures is exported under ignored tmp with private permissions. The development mode uses separately owned schemas containing the test naming token and changes no application or deployment mapping.

OTLP controls run the actual SDK.configure/use_all path in isolated subprocesses, serialize and decode actual protobuf bytes at a synthetic loopback collector, and observe exporter outcomes, force_flush, shutdown, HTTP failure and bounded timeout. SDK isolation targets the actual NetHttp terminal handler and leaves native response stubs and serialization intact. No live AWS capability is required.

WebConsole runs through actual development boot and middleware with loopback/foreign-IP injection controls. Kamal parses the real host configuration and an authored synthetic configuration. Thruster wraps actual Puma on owned loopback ports and checks an authored public-cache response, request limits, shutdown, both closed ports and the absent process group. Real Rails home and health requests also pass through the proxy to the actual development application, with home content and layout controls. Its separately owned schemas are prepared only while physically empty. The worker boundary separately loads actual bin/jobs, observes its async supervisor/dispatcher/worker registrations and checks graceful shutdown. The existing browser fixtures exercise actual source Bootstrap/importmap behavior through installed Selenium. Real SSH, Kamal deployment and AWS writes are outside scope.

## Evidence and current limits

The original missing-donor run remains retained: ordinary RSpec reached one pending queue migration, ran zero examples and reported nine load errors. The preliminary focused run reached thirteen examples without failures but exited 2 on the unchanged coverage floor. These remain failed or partial readbacks, never ordinary-suite acceptance.

The first ordinary run after #77 integration reached 264 examples with one failure. Its Unicode fixture expected eleven Solid Queue tables instead of the new thirteen. A recorded, narrowly owned adaptation now asserts exact Solid table names including both official additive tables and retains all encoding, collation, emoji, negative and physical cleanup controls.

An attempted old-witness readback after that ordinary run failed. Normal Rails test preparation uses source schema fingerprints and can rebuild or truncate test schemas when their dump changes. Old-bundle preservation/migration/runtime therefore run on their own physical resource, and the ordinary suite uses a separate fresh resource loaded from the current generated schemas. No test-preparation policy is bypassed, no synthetic fingerprint is written and no further ordinary preparation runs over preservation witnesses. Failed diagnostics remain retained.

The final separate preservation run retained all old Solid rows through the bundle switch and additive migration, then observed worker effects, retained scheduled and failed jobs, cache bytes and cable behavior. Its read-only fingerprint check confirmed that the queue schema was stale for ordinary test preparation. The separate unfiltered ordinary suite passed with 264 examples, zero failures, 96.98% line coverage and 90.43% branch coverage. Its runtime source hashes match the preservation run after formatting the actual generated schema. All five recurring-worker controls passed against that schema. Each resource reports positive container, volume, process, port and scratch cleanup.

The first ordinary lint readbacks remain retained: ten RuboCop findings and seven Reek findings. The subsequent explicitly coordinated correction converts the existing single-statement directives to disable-next with the same cops and justifications, fixes literal matching and indentation, and refactors AwsBootstrap without changing its public load! keyword defaults, dummy/task guards, flags, selectors, pagination, ENV precedence or sanitized failures. A bounded BootPolicy owns enablement and deployment decisions. The class invokes the actual instance load operation, while the original public instance load! remains an alias with identical return and failure behavior. No detector configuration changes or additional suppressions are added. The original six #77 committed blobs remain exact; its one admitted fixture comment change has an identical executable AST.

The unchanged loader baseline reached 39 boot/loader examples without assertion failures. Expanded loader and SDK controls reached 64 examples without failures before and after the runtime refactor. These focused runs exited 2 under the unchanged coverage floor and are not ordinary-suite acceptance. The current ordinary suite then passed all 307 examples, including 43 additional loader contract controls, with 98.44% line coverage and 92.55% branch coverage. Ordinary RuboCop passes all 98 files and Reek reports no findings. The current Brakeman readback has zero warnings or errors; the earlier successful updated vulnerability audit applies to the unchanged lock and installed library bytes. The official4.67 checker alias is an installed prerequisite with a verified import closure, and does not establish clean frozen package adoption or the eight managed major upgrades.

The earlier checks above describe their recorded donor revisions. The combined batch adopts all eight managed majors from the published constraints; fresh combined-suite and hosted results must be assessed separately. See tooling-advisories.md for the current npm audit and bounded residual dispositions.
