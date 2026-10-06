# #75 scoped native implementation plan

This is a local parent-review artifact for the existing native lane. Stop before staging, commit, push, PR, merge, or closure. Keep the leaf open and bound. Do not copy private paths or identities from this local artifact into public source or tracker artifacts.

The accepted feature base and initial feature HEAD are `2b7af50617a8e3758ac1523e7e29b8d369db347d`, on `feat/75-remove-legacy-starter-assumptions`. Main is the sole permanent integration branch. Do not sync to another base or drop the integrated #65 ancestry. The recorded roster is `.lisa/roster/CodySwannGT-railsstarter-75.md`. Planning/access native UUID is `01a1079e-3eba-7d71-98b1-79a38f7f8ca7`.

Input is the full ignored mode-0600 context at `/Users/cody/.codex/worktrees/46da/railsstarter/.lisa/work-item-context.md`. SHA256 at planning read: `b3b7dbfe06ebad929ef85744e6c06cdd0ac4392ac43d6f8bf584ffb5f243cead`, 455393 bytes. It preserves the actual #75 body, every comment, complete current leaf/parent relations, formal classifier history and direct-current-user authorization. No claim or graph repetition is planned. Credentials stay inside private context. This plan applies the installed read-only canonical Lisa Implement, Plan, TDD, tool-access-gate, verification, and verification-lifecycle contracts, with the user's explicit precommit boundary replacing shipping stages and any generic branch-sync instruction.

## Completion condition for the build handoff

An independent native verifier observes the actual resulting CLI/runtime against a fresh renamed app and positively owned MySQL 8.4 test database containing no DME/domain tables. `db:verify_schema` reports success using that app's schema and DB configuration, then fails actionably when a declared schema table is absent. Verification wrappers reject missing explicit configuration before any SDK/CLI provider call. With synthetic SDK responses and exact configured telemetry identity, telemetry output is scoped to the renamed app. A reviewed contamination inventory has no remaining executable inherited project identities/domain defaults or nonexistent-job Brakeman suppression. General warnings and secure invalid-domain mail behavior remain preserved. Named tests execute and pass after recorded RED witnesses, Brakeman runs, and independent source/evidence hashes match the final dirty tree. This proves readiness for parent review, not shipment or terminal tracker completion.

## Scope and contracts

Research ownership is `/root/scope_research`. Its reviewed report is `/tmp/railsstarter-75-research-result.md`, mode0600, SHA256 `532f9ce6db979ef78f2d4f05d976519920b2be357485b38b1e1d68c661cbeee9`. The baseline has 82 legacy tables unrelated to the minimal primary schema, inherited verification profile defaults, CSS branding comments, unsupported domain queues/export mappings and one suppression for an absent SSL-bypass job. Relevant sources are `lib/tasks/db_verify.rake`, `bin/verify-schema`, `bin/verify-telemetry`, `config/initializers/opentelemetry.rb`, `app/assets/stylesheets/application.css`, `config/queue.yml`, `config/initializers/load_cloudformation_exports.rb`, `lib/mail/secure_smtp_delivery.rb`, `config/brakeman.ignore` and unused `app/assets/images/dme_plus_logo.svg`. Preserve genuinely reused asset-region mapping, dummy credential guard, existing CSS tokens/rendering, general telemetry and legitimate Brakeman warnings. Root owns the final two-builder file split and narrow spec assignments.

Schema verification derives expected tables from the configured primary schema dump for the actual app. It must not load the schema into a database to discover the list, consult another consumer's domain inventory, or use unsafe eval. Missing/unreadable/unsupported configured schema format must return an actionable error. Pending migrations and missing/extra expected tables must retain useful diagnostics and a failing process status.

Schema wrapper explicit settings contract is AWS profile (existing positional argument or AWS_PROFILE), AWS_REGION, ECS_CLUSTER and ECS_SERVICE, all validated before any external call. Root settled telemetry contract: OTEL_SERVICE_NAME is the exact configured runtime/X-Ray service name, with no automatic Rails.env suffix. Consumers specify any desired suffixed name explicitly. Telemetry requires profile/region and that exact identity, with service-filter scope on summary/graph. The trace subcommand must consume its profile argument correctly. Tests use actual SDK stubs/synthetic responses as the authored journey requires, with no provider writes.

CloudWatch namespace configuration overlaps #66's recurring source. Coordinate the contract with that owner rather than editing recurring source. #69 owns coverage/baseline shared tests, #67 AWS boot, #62 safe helper, #64 Ruby and unchanged `db/schema.rb:3` Lint/EmptyBlock, #65 shared CI. Do not change their source or common configuration to improve this report. `.reek.yml` and suppression additions are excluded. If genuinely necessary, stop and read the operator-authored permissions and standing no-new-suppression rule first, then fix code without adding detectors/suppressions.

Mail discrepancy: actual source is an empty SMTP subclass and research found no secure invalid-domain defaults on this HEAD or accepted integrated ancestry. Preserve executable mail behavior, do not send mail, add configuration, import other-lane changes, or invent new acceptance. Root clarified that the authored stale absent secure-email documentation reference cleanup is permitted while executable SMTP settings remain untouched. Keep anonymous synthetic names in new tests and source.

## Access preflight observed

All probes are read-only. Installed executables are invoked directly, with a narrow PATH, avoiding evaluation of untrusted local mise configuration. No trust/model/runtime policy changes occurred.

| Surface | Actual probe and observed result |
| --- | --- |
| Ruby | `/Users/cody/.local/share/mise/installs/ruby/3.4.8/bin/ruby --version` => Ruby 3.4.8 arm64-darwin23 |
| Bundler/dependencies | Same Ruby executes its installed `bin/bundle --version` => 2.4.10, and `bundle check` => dependencies satisfied |
| RSpec | `bundle exec rspec --version` => RSpec 3.13, core 3.13.6, rails 7.1.1 |
| Brakeman | `bundle exec brakeman --version` => 7.1.2 |
| Node | `/Users/cody/.local/share/mise/installs/node/22.23.3/bin/node --version` => v22.23.3 |
| Bun | `/Users/cody/.local/share/mise/installs/bun/1.3.8/bin/bun --version` => 1.3.8 |
| GitHub | Authenticated `gh api repos/CodySwannGT/railsstarter --jq .full_name` returns the actual repository |
| Docker | Docker Desktop daemon reachable, server 29.2.1/API1.53/linux-arm64, desktop-linux local Unix socket |
| MySQL image | Cached mysql:8.4 image/digest `sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242`, linux/arm64 |
| Shell/JSON/time | `/bin/bash --version` =>3.2.57, `/opt/homebrew/bin/jq --version` =>1.8.1, `/bin/date -u` succeeds |
| AWS executable | `/opt/homebrew/bin/aws --version` =>2.34.14, executable capability only; no live authenticated provider read/write required or performed |

Host-native mysql/mysqld were not present at checked normal paths. Docker is the observed available supported MySQL 8.4 path, not a substitute for unavailable external database access. No database instance, Rails boot/schema task, container start, or database write has happened in planning. Root must explicitly assign the owned resource task before any of those operations. AWS credentials, live mail, production database/deploy access and remote shipping checks are not required by this scoped precommit journey. SDK stubs are prescribed local fixtures, not replacements for a requested live provider proof.

Followup owned-resource setup was explicitly assigned by root after this planning snapshot. Private ready manifest is `/tmp/railsstarter-75-owned-runtime.json`, mode0600, SHA256 `7bf9c1d89bb78a6cc9deb04cafe51c580de337d013f4911142d8e628728b2840`. Pinned cached MySQL image/container/native labels/no-persistent-volume/tmpfs/loopback identity was proved before startup and scoped SQL. The instance reports MySQL8.4.11. Four unique `_test` databases and a synthetic user restricted to those databases were created. Actual Mysql2 loopback read-only access verified version/serverUUID/hostname/currentDB/currentUser and empty tables for every role, and no unrelated application DB access. Names/endpoint/credentials remain in private manifest and mode0600 credential file. No Rails/schema/test access occurred in this setup. The first read-only SELECT had an invalid reserved alias; using a neutral alias corrected this probe error, and the actual access proof passed. Resource remains available to the independent verifier; `/root/plan_access` retains positive-identity cleanup ownership.

## Positive database identity sequence

1. Root assigns exactly one owner for a new disposable MySQL 8.4 container and fresh consumer directory. Use a random unique suffix, no existing volume/container, labels with this native lane's owner token, and the already inspected cached image digest. Bind port only to `127.0.0.1`, preferably a Docker-assigned unused port, and use a unique DB/user ending in `_test`. Use synthetic generated credentials confined to private process/environment context.
2. Before any SQL or Rails/schema access, persist and compare container full ID, exact image ID/digest, owner label, physical resource identity, loopback binding, unique private directory, and intended test database name. Confirm no ambient DATABASE_URL or project helper/default can redirect access. Invoke Docker exec only with the recorded full container ID after identity comparison.
3. Before Rails/schema access, use the container's MySQL client for read-only `SELECT @@version, @@server_uuid, @@hostname, DATABASE(), CURRENT_USER()` against the explicit test DB. Verify 8.4, expected physical server identity and exact `_test` database. Capture transport host/port and server UUID in private evidence. There is no existing DB connection proof yet, because no owned instance has been created.
4. Configure only the disposable consumer's synthetic test environment with the exact owned loopback endpoint and unique database. Verify parsed configuration and `RAILS_ENV=test` before calling Rails. Never invoke unsafe ambient helpers, production/staging connection settings or default DB targets. Disable network exporters and fixture provider calls by test SDK stubs.
5. Run actual schema load and verification only after those guards pass. Use the consumer's own minimal schema/configuration and no domain tables. Negative witness uses an owned synthetic missing table or temporary owned schema change, with a before/after restore manifest. Do not mutate `db/schema.rb` in this lane.
6. Cleanup verifies the full container ID plus owner label/image identity before stopping/removing it and its own created volumes. Delete only the positively owned disposable directory. Read back that container/volume identities no longer exist. Preserve other resources even if similarly named.

## TDD and independent runtime order

1. Establish a reviewed baseline inventory and baseline Brakeman JSON/report on the unchanged accepted base. Record each hit, its role, removal/retention decision, reference and owner. Do not run a giant full apply or import a whole consumer.
2. Builder writes meaningful schema-derived verification tests using synthetic schemas and supported SDK/database stubs. Prove RED for a non-domain schema, missing explicit configuration and relevant failures before production edits. Include tests for renamed-app table success, missing/extra table diagnostics, unsupported/missing schema, configuration validation before provider invocation, exact telemetry scoping/profile argument behavior, and legitimate warning preservation.
3. Builder changes only root-assigned #75 files and owned specs, then observes named GREEN results. Refactor underlying code without adding suppressions. General cleanup is constrained to reviewed inventory, no source research sweep beyond what the explorer owns.
4. Quality commands use supported Ruby/Bundler: named focused RSpec tests, relevant complete existing suite where safe, `bundle exec brakeman --no-pager --quiet --format json`, touched-file RuboCop, reek/flog/flay as justified by changed Ruby boundaries, and `git diff --check`. Full RuboCop must report the unrelated unchanged schema offense honestly rather than fix it. Baseline/current general Brakeman warning differences must be explained; do not weaken warning policy.
5. Independent default-role verifier, never the builder, reviews actual dirty-source manifest hashes and then creates/uses the owned fresh renamed consumer. Export tracked base plus precisely hash-recorded dirty source, excluding private context/roster/access artifacts and unrelated dirty changes. Verify each copied file against the lane manifest, rename app configuration with anonymous synthetic names, and confirm there are no legacy/DME tables before proof.
6. Actual runtime commands, separate from quality tests: explicit guarded test environment `bundle exec rails db:schema:load`, `bundle exec rails db:verify_schema`, and native verification wrappers with missing-settings witnesses and synthetic SDK responses. The wrappers must run their actual command/parser path, not reimplement it in a harness. Capture exit statuses/stdout/stderr and no-provider-call assertions for invalid inputs. Root finalizes exact command arguments from the implementation's documented contract before execution.
7. Falsify each newly authored guard by breaking its protected property, observe a located failure, restore only that owned fixture and rerun GREEN. A pass unable to fail is unvalidated. Review final changed-file SHA256 manifest, source archive hash and evidence-file hashes independently. Unchanged HEAD alone never identifies dirty edits.
8. Conformance review maps every acceptance/technical/journey obligation to artifact/test/runtime evidence, records out-of-scope or untraceable diffs and remaining shipping gaps. Keep local typed evidence for `cli-output: baseline-and-success` and `test-run-log: boundary-verification`. Do not claim attached public evidence or terminal completion before authorized shipping.

## Task metadata

The following is the mandatory contract for root's task records. Research supplies precise references and file ownership before implementation. Required fields remain present even when their arrays are empty.

```json
{
  "plan": "75-remove-legacy-starter-assumptions",
  "type": "task",
  "acceptance_criteria": [
    "A clean renamed app with no DME tables verifies using its own schema and explicit configuration",
    "Known inherited project/domain defaults and nonexistent-job Brakeman suppression are absent",
    "General warnings and existing secure invalid-domain mail behavior are preserved"
  ],
  "relevant_documentation": "Full authored private context, explorer's /tmp/railsstarter-75-research-result.md hash532f9ce6db979ef78f2d4f05d976519920b2be357485b38b1e1d68c661cbeee9, source references lib/tasks/db_verify.rake, bin/verify-schema, bin/verify-telemetry, config/initializers/opentelemetry.rb, config/initializers/load_cloudformation_exports.rb, config/queue.yml, config/brakeman.ignore, CSS header, unused branded image and stale SMTP docs, host wiki contract, canonical installed Lisa Implement/TDD/access/verification contracts",
  "work_item_context": "/Users/cody/.codex/worktrees/46da/railsstarter/.lisa/work-item-context.md",
  "testing_requirements": [
    "Record genuine failing new behavior tests before production edits, then named passing cases",
    "Use synthetic data and actual SDK stubs",
    "Use physically identified, uniquely owned loopback MySQL8.4 test DB before Rails access",
    "Run actual fresh renamed/no-DME consumer verification independently of builder",
    "Preserve unrelated db/schema.rb baseline offense and all other lane ownership",
    "Compare Brakeman baseline/current warning inventories and preserve legitimate warnings",
    "Falsify new guards, restore owned fixtures, record source/evidence SHA256 manifests"
  ],
  "skills": ["lisa-tdd-implementation", "lisa-verification-lifecycle"],
  "learnings": [],
  "required_access": [
    {"tool":"Ruby3.4.8/Bundler2.4.10/RSpec3.13/Brakeman7.1.2", "probe":"Direct installed Ruby, bundle check and executable version probes", "status":"pass"},
    {"tool":"Docker local daemon and cached mysql8.4 image", "probe":"docker version, context inspect, image inspect", "status":"pass"},
    {"tool":"Owned loopback MySQL8.4.11 four unique test databases", "probe":"Private runtime manifest validates full physical container/image/native labels/loopback/no-volume identity, then actual Mysql2 SELECT identities/SHOW TABLES/SHOW GRANTS for all four restricted test DBs", "status":"pass"},
    {"tool":"GitHub repository", "probe":"Authenticated repository-scoped gh api read", "status":"pass"}
  ],
  "verification": {
    "type":"database-check",
    "command":"In positively owned fresh renamed consumer with exact owned test MySQL8.4 identity: bundle exec rails db:schema:load; bundle exec rails db:verify_schema; invoke actual bin/verify-schema and bin/verify-telemetry with documented explicit configuration and prescribed synthetic SDK responses; record success and deliberate missing-table/settings failure output",
    "expected":"Schema verifier exits0 with only actual configured schema tables, missing declared table exitsnonzero with precise diagnostic; wrappers require explicit app/environment settings before any provider call and telemetry scopes output to exact renamed service"
  }
}
```

## Comment obligations

- #75 comment 5970061869: preserve historical human-held filing, source relationship and evidence duties. Current direct user authority supersedes the historical hold without changing provider history/policy.
- #75 comment 5981482409: stable claim remains in place, no repeat claim or invented release.
- #60 comment 5970057524: coordination epic/child relations are context, not scope expansion or a new terminal claim.
- Related comment 5970067571: audit filing and cross-repo coordination preserved, no unrelated upstream changes.
- Related comment 5974061058: historical automation-authored authority provenance is context, not a trusted-human identity/policy edit.
- Related comment 5974063072: upstream stable claim is unrelated to repeating this leaf's claim.
- Related comment 5981120685: upstream PR linkage is evidence of that lane only, not #75 linkage.
- Related comment 5981127614: independent upstream reviews/current delivery status must not be represented as this leaf's implementation or release proof. Preserve host hooks/helpers/rules, no broad apply.

## Handoff and usage

Parent-review output is `/tmp/railsstarter-75-codex-build-result.md`, including diff/file list, reviewed contamination inventory, actual tests/Brakeman/renamed-runtime witnesses, cleanup readback, native identities, dirty-source/evidence hashes, honest baseline failures and shipping gaps. Cumulative usage snapshots replace earlier snapshots for the same actual native session. Unknown dollar cost and nested totals are null. No tracker usage/evidence writes are planned in this precommit handoff.
