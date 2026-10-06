# Official upstream contract research: CodySwannGT/railsstarter#65

**Latest refresh:** the final section records published4.68.1 and supersedes initial4.68.0 latest/inclusion observations. It includes #4334, while #4335 remains a publication prerequisite.

Research only. No implementation, project installation/apply, test execution, CI dispatch, tracker mutation, commit, push, PR, merge or closure occurred in this lane. This artifact is sanitized and trackable. It is the exclusive output of the upstream-contract-research specialist, under the recorded per-issue roster. Model and safety settings were inherited unchanged. All other work remains outside this lane.

```json
{
  "plan": "CodySwannGT-railsstarter-65-ci-workflow-migration",
  "type": "spike",
  "acceptance_criteria": ["Provide current sourced research for assigned scope, with no implementation"],
  "relevant_documentation": "Lisa Implement roster/research/access gates, official published source and complete resolved context",
  "work_item_context": "/Users/cody/workspace/railsstarter/.claude/worktrees/65-ci-workflow-migration/.lisa/work-item-context.md",
  "testing_requirements": ["No tests/build/CI mutations during research", "Future PR proof must execute meaningful nonzero examples, actual gates and retained default-branch schedules"],
  "skills": ["lisa-implement"],
  "learnings": [],
  "required_access": [
    {"tool":"GitHub official source","probe":"gh api repos/CodySwannGT/lisa/commits/v4.68.0 and contents endpoints at exact SHA","status":"pass"},
    {"tool":"npm registry metadata","probe":"npm view @codyswann/lisa@4.68.0 version gitHead dist.integrity dist.tarball engines lisaReleaseCommit lisaReleaseTag --json through explicit installed Node PATH","status":"pass"},
    {"tool":"published package source","probe":"read existing npm cache exact tarball key, compare SHA512 with live registry, extract only to private temporary directory","status":"pass"},
    {"tool":"installed supported Node/Bun","probe":"explicit installed Node22.21.1 and Bun1.3.8 --version","status":"pass"}
  ],
  "verification": {"type":"documentation","command":"Read this artifact and match findings against the cited immutable official sources and recorded observational outputs","expected":"Supported interfaces, limitations and future empirical proof commands are concrete, with no source implementation"}
}
```

## Isolation, instructions and context

Initial observed cwd `/Users/cody/workspace/railsstarter/.claude/worktrees/65-ci-workflow-migration`, branch `codex/65-ci-workflow-migration`, status had `.claude/settings.json` modification and untracked `.lisa/` artifacts. No binding/claim transaction was repeated. The resolver's existing base is `31517fd9aa0c4baf3e5eaecc3d9f7b4c5f271a44`, PR target `main`. Main remains the only permanent remote integration branch. Private `.lisa.config.local.json` `deploy.branches.dev=main` is a validator environment mapping, never permission to create dev/staging branches.

Read task prompt, roster, AGENTS, PROJECT_RULES, Lisa Implement roster/research/access sections, wiki orientation/index/contract, and parsed every JSON section of the complete ignored context. The context contains three complete JSON sections and 64 unique issue/comment bodies across 28 captured issues and 36 comments. The per-comment inventory preserves historical audit holds and automation-authored authorization. Current bounded user authorization supersedes the historical hold only within delegated scope, without rewriting trusted-human policy. Existing source precedence and main-only rules win over stale staging examples in PROJECT_RULES. Wiki index has orientation/staff links but no populated engineering synthesis, so current official package/source inspection supplies the contract evidence.

AGENTS later acquired managed host-rule/learnings bridges during another lane's diagnostic work. This specialist did not run doctor or any normalizer. `.agents/rules/` was absent at both checks. Config-resolved `.lisa/PROJECT_LEARNINGS.md` was absent, so no ledger was read raw or projected. The installed doctor implementation explicitly normalizes instruction files, documented below.

## Published and installed identity: initial 4.68.0 snapshot

Observed registry latest is **4.68.0**. The current upstream main, `v4.68.0` resolution, registry `gitHead` and packed `lisaReleaseCommit` all resolve to `728d35afbd3de4d522023e0b65fd0f730c94820c`, dated 2026-10-03T15:36:44Z. Installed shared Lisa remains **4.67.0**, stamped `v4.67.0` and `4bb326e655301ad1188a57583b804fc03fe29003`, whose GitHub tag resolves identically, dated 2026-10-02T21:11:07Z. This is source inspection, not consumer adoption or fresh CI proof.

Registry integrity for 4.68.0:

`sha512-0O+qO+g6psWj5J1hX9N743t7MhQjeM0w0vYgLFVXCGED4TCdVVWa13bJlDnl63hqzapi/6Wdhlw0ljqTU9qflA==`

Tarball URL: https://registry.npmjs.org/@codyswann/lisa/-/lisa-4.68.0.tgz

Package source was obtained by **reading existing cache** with npm's `cacache.get` for the exact request key, not by installing. The full 13,883,639-byte cached tarball matched the live registry SHA512. Extraction with Python `tarfile.extractall(..., filter="data")` went only to `/var/folders/_2/29n6gy1s42777swvq24j3fh00000gn/T/railsstarter-65-upstream-ftbz9q7v/package`. No lifecycle scripts ran and shared cache was not mutated. Direct downloads were readable but slow and timed out, then were cancelled by the exact anchored curl command belonging to this lane. These transport timeouts were not credential failures. An incomplete temporary download was never used as package evidence.

Official immutable compare from 4.67.0 to 4.68.0 reports five commits, principally Lisa self-update and release changes. The actual extracted packages confirm **all 41 Rails files byte-identical**, as are the project config reader/type schema, reusable-workflow pin/release-pin/deletion guard, Rails deploy intent checker/classifier, worker epoch/journey code and config-resolution reference. No initializer or hook-continuity correction is delivered by this version comparison. Current work on #4334/#4335 must reach merge, release, registry and consumer readback before it can be reported as published adoption.

Sources: [official compare](https://github.com/CodySwannGT/lisa/compare/4bb326e655301ad1188a57583b804fc03fe29003...728d35afbd3de4d522023e0b65fd0f730c94820c), [4.68 release source](https://github.com/CodySwannGT/lisa/tree/728d35afbd3de4d522023e0b65fd0f730c94820c), [registry metadata](https://registry.npmjs.org/@codyswann%2Flisa/4.68.0).

## Coherent pins and ownership

Supported consumer reusable refs are the **full SHA stamped by the installed package**, with a matching `# v<version>` comment. The release pinner refuses malformed or absent release identity rather than silently falling back to main. The current coherent choices are package 4.67.0 plus SHA `4bb326e655301ad1188a57583b804fc03fe29003`, or normal adoption of published package 4.68.0 plus SHA `728d35afbd3de4d522023e0b65fd0f730c94820c`. Never pin today's upstream tip while retaining an older installed package. Implementation must refresh the registry and adopt the actual released fixes if those are prerequisites, then use their stamped SHA instead of either dated value here.

The raw create-only templates still spell `@main`, with comments from an earlier tracking policy. That is input to the apply-time pinner, not the final consumer contract. `src/core/reusable-workflow-pin.ts` and `src/core/lisa-release-pin.ts` are the authoritative executable consumer pinning path. The internal `check-template-workflow-refs.mjs` still audits raw templates for tracking refs, so do not run it against final consumer files and confuse that check with consumer SHA conformance.

Third-party action pins require a full SHA plus readable version comment. The reviewed quality workflow pins ruby/setup-ruby to `95ef2b042f9d7a56d8268cba8559e2842e2ad01b # v1.321.0`, setup-bun to `0c5077e51419868618aeaa5fe8019c62421857d6 # v2.2.0`, and FOSSA action to `c414b9ad82eaad041e47a7cf62a4f02411f427a0 # v1.8.0`. The official ordinary third-party policy exempts GitHub-owned `actions/*` and `github/*`, so their `@v6` refs are permitted there. Consequential publishing ancestry is stricter in readiness. There is no authorized publishing path for this starter stage.

Workflow create-only ownership means seeded files belong to the host and full apply does not overwrite or blindly delete them. Only explicit Lisa-managed headers establish deletion ownership. A path in the retirement manifest with `needs-review` is evidence that review is needed, not permission to delete unidentified host bytes. Preserve startup plugin settings and every host hook. Reusable scripts marked copy-overwrite must remain exact official artifacts, with durable improvements upstream.

Sources: [consumer pinner](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/src/core/reusable-workflow-pin.ts), [release identity resolver](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/src/core/lisa-release-pin.ts), [deletion ownership](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/src/core/workflow-deletion-ownership.ts), [third-party detector](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/all/copy-overwrite/scripts/check-third-party-action-pins.mjs).

## Exact reusable interfaces

### quality-rails.yml

[Immutable source](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/.github/workflows/quality-rails.yml). No declared workflow-call outputs. Inputs are:

| Input | Type/default | Starter plan |
|---|---|---|
| expected_workflow_contract_major | string, empty | `'1'` beside the uses line |
| database_type | string, postgres | `mysql` |
| database_name | string, test | Preserve or explicitly choose synthetic test database compatible with project database.yml |
| database_version | string, empty | `'8.4'` to match known MySQL image and local verification |
| expected_work_item_contract | string, 1.1.0 | `'1.1.0'`, matching upgraded script contract |
| skip_jobs | string, empty | Keep empty. No gate exemptions |

Caller must grant the callee floor: `contents: read`, `checks: write`, `pull-requests: write`, and `issues: read` for GitHub tracker proof. There is intentionally no reusable workflow-level permissions ceiling. All declared secret inputs are optional: `GITGUARDIAN_API_KEY`, `FOSSA_API_KEY`, `JIRA_API_TOKEN`, `JIRA_LOGIN`, `LINEAR_API_KEY`. Github tracker uses the run token. Jira/Linear credentials are unused for this repo's tracker. GG/FOSSA absence invokes explicitly labelled optional-scan skip paths, which does **not** prove a separate required external GitGuardian context. The acceptance/access lane owns exact provider access and live rulesets.

Actual job names: Workflow Contract, Which Lisa Ran This, Lint, Threshold Ratchet, Work-Item Traceability, Security, Test (PostgreSQL), Test (MySQL), Mutation Testing Gate, Code Quality, Credential Leakage, Structural Rules, Learnings Budget, Licence Check, including their displayed emoji. Caller `name: Quality Checks` produces the established contexts such as `Quality Checks / Lint`, `Quality Checks / Security`, `Quality Checks / Code Quality`. The exact runtime check names must be read from actual head/check-suite evidence, not guessed from YAML.

MySQL route runs db:prepare followed by `bash scripts/lisa-scratch-run.sh --suite rspec-mysql -- bundle exec rspec`. Its service image accepts database_version and defaults to 8.0 if omitted. Missing scratch script fails closed. Threshold ratchet requires `scripts/check-threshold-ratchet.mjs`, plus its imports `threshold-ratchet-families.mjs` and `threshold-ratchet-compare.mjs`, and compares origin/base. Missing script/base fails closed. Work-item traceability checks event payload SHAs and PR head, uses contract 1.1.0, verifies the tracker backlink and inherited issue/PR access. Baseline absent script/config can cause an unenforceable skip path, so a green skipped traceability step is unacceptable proof here: retain the real script/config and inspect log evidence of actual validation. MySQL does not run the Postgres-specific mutation job by upstream schema, an inherent interface limit rather than a new skip token.

### gates.yml

[Immutable source](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/.github/workflows/gates.yml). No declared secrets or outputs. `moment` string required. Optional: expected_workflow_contract_major(string empty, use1), node_version(string22.21.1), package_manager(string npm), working_directory(string empty), install_dependencies(boolean true), timeout_minutes(number60), ref(string empty). Caller floor contents:read. This is a deterministic declared-gate façade, not a code-improvement worker. Unsupported moment or killed/unknown run fails. Evidence envelopes are records, not self-authenticating proof of GitHub check posting.

The continuous seed requires at least one declared gate for its selected continuous environment and fails when the set is empty. Do not retain a scheduled green no-op or configure a live-target gate without its target. A starter-only dependency prover can use real Bundler/npm advisory sources with the corresponding install/setup prerequisites, but its runner and moment legality must be explicitly validated. Default production naming in the seed does not create or authorize a production target.

### Other official scheduled caller interfaces

`workflow-load-failure-sweep.yml` is a **local caller**, not workflow_call. It needs Node22.21.1, gh, `contents:read`, `actions:read`, and the official local detector plus imports. It runs `node scripts/check-workflow-load-failures.mjs`, derives the population from actual caller files, scans a 26-hour window with a 20-page cap, and reports uncovered windows as failures. It can observe load failures even when a callee fails to load.

`lisa-update.yml` is a **local caller**, not workflow_call. The 4.68 consumer seed uses a PAT for GitHub-triggered PR CI and keeps credentials out of dependency installs via LISA_UPDATE_TOKEN. It needs a real PAT secret, current pinned Bun and Node22.21.1, plus `scripts/lisa-self-update.mjs`. It creates issues/PRs/commits during runtime, so this stage must not activate or dispatch it. It is dependency maintenance, not replacement evidence for retired test/complexity code-improvement workers. Current upstream .github/lisa-update has a Lisa-self-specific Release and Deploy workflow_run addition. Consumers should inspect their create-only seed, not copy the upstream self workflow indiscriminately.

Sources: [continuous seed](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/all/create-only/.github/workflows/continuous-gates.yml), [load sweep seed](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/all/create-only/.github/workflows/workflow-load-failure-sweep.yml), [update seed](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/all/create-only/.github/workflows/lisa-update.yml).

## Disabled deployment: actual supported semantics

There is **no documented or executable `deploy.enabled`, `deploy.disabled`, or equivalent deploy-enable boolean** in the reviewed 4.67/4.68 consumer package/config reader/templates/reference. ProjectConfig preserves unknown keys on round-trip, which is not evidence that an unknown key controls execution. An invented `deploy.enabled:false` would leave GitHub workflow triggers executable.

The supported Rails doctor interface is file-based: absent `.github/workflows/deploy.yml` reports ok; a main push trigger reports production deployment configured; a commented main entry accompanied by the actual AWS_ACCOUNT_ID_MAIN precondition explanation reports deliberate withholding. The latter template still permits manual workflow_dispatch, so it proves only withheld automatic production deployment, not fully disabled delivery. Removing staging's automatic trigger alone likewise cannot prove dispatch is disabled.

For this main-only starter with no available live deployment target, plan an explicit host-owned retirement/removal of the active deploy caller (with durable rationale and future enabling prerequisites), or an equally explicit host workflow that carries no executable deployment surface. Do not use placeholder success jobs. The reviewed installed/published release supplies no global boolean switch. This is an implementation planning decision derivable from the authorized scope, not a request to reconsider permanent branches or procure unused AWS targets. Deployment-disabled proof must inspect every retained workflow's actual triggers/jobs/reusable callees and confirm no release/deploy path executes.

Sources: [doctor deploy-intent checker](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/src/cli/doctor-rails-deploy-intent.ts), [intent classifier](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/src/core/rails-deploy-production-intent.ts), [host deploy seed](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/rails/create-only/.github/workflows/deploy.yml), [config contract](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/plugins/src/base/rules/reference/config-resolution.md).

## Retirement dispositions and exact candidate files

The official Rails deletion manifest lists all five old caller paths with `basis: needs-review`, and the official current upstream workflow list contains none of their old callees. There is no supported filename-for-filename reusable replacement for the three old autonomous improvement nightlies or review-response caller. Preserve purposes in a reviewed disposition, not mechanically rename to a non-equivalent worker.

| Consumer path | Bounded disposition |
|---|---|
| .github/workflows/claude-code-review-response.yml | Retire obsolete callee after recording review-response purpose and replacement by existing reviewed PR remediation flow/provider. Do not claim deterministic CI is an autonomous review-response worker |
| .github/workflows/claude-nightly-code-complexity.yml | Retire missing autonomous improvement callee. Retain complexity enforcement through actual quality Code Quality job, and document improvement through reviewed issue work. Any replacement worker needs epoch qualification and separate explicit activation |
| .github/workflows/claude-nightly-test-coverage.yml | Retire missing autonomous improvement callee. Preserve real RSpec/SimpleCov thresholds in PR CI, and choose a scoped deterministic retained schedule only with a nonempty real prover |
| .github/workflows/claude-nightly-test-improvement.yml | Retire missing autonomous worker with explicit reviewed-test-maintenance rationale. A dependency scan does not replace its test-authoring capability |
| .github/workflows/claude-sync-down-branches.yml | Remove branch-sync caller with single-main topology rationale. No dev/staging creation |
| .github/workflows/ci.yml | Host-owned supported quality call, coherent SHA/version, mysql8.4, contracts, permissions and real gates |
| .github/workflows/deploy.yml | Explicit no-target retirement/disabled executable surface, with rationale, because config has no supported enable boolean |
| .lisa.config.json | Align truthful gate declarations and main-only deployment topology without weakening required checks or trusted-human settings |
| package.json and lockfile | Normal published Lisa version resolution, actual check:work-item command, toolchain pins where owned |
| scripts/lisa-scratch-run.sh | Exact published Rails supervisor |
| scripts/check-threshold-ratchet.mjs, scripts/threshold-ratchet-families.mjs, scripts/threshold-ratchet-compare.mjs | Exact published comparator bundle |
| scripts/lisa-work-item.mjs and official runtime imports as needed | Real contract1.1.0 validator, preserve correct worktree binding |
| Selected retained scheduled caller and its official script/imports | Only what the parent deliberately scopes and can prove on default main after merge |

`check:work-item` exact official package command is `node scripts/lisa-work-item.mjs validate-pr`. It is present in the official TypeScript package-lisa template and upstream package manifest. The Rails-only template directory does not contain a package-lisa manifest, so do not assume a Rails apply automatically supplies this declaration. Add/align the host command if its gate is declared. Do not import the entire TypeScript tooling suite into a Rails starter to obtain one command.

Source: [Rails retirement manifest](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/rails/deletions.json), [official command declaration](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/typescript/package-lisa/package.lisa.json).

## Toolchain and doctor/check qualification

Published4.67/4.68 engine pins are Node22.21.1, Bun1.3.8. npm/yarn/pnpm engine strings say please-use-bun. Read-only metadata/cache inspection via npm is not project dependency installation. Initial shell had no node/npm on PATH and mise exec refused the untrusted local .mise.toml. No mise trust/settings change was made. Explicit installed binaries passed Node22.21.1 and Bun1.3.8 --version. Use them or the documented setup in the future implementation lane. Ruby3.4.8 comes from existing project policy and .ruby-version, and acceptance specialist owns live Ruby/Bundler/database probes.

Quality-rails exposes no Node/Bun/Ruby version inputs. Ruby setup follows .ruby-version; the learnings gate explicitly selects Bun1.3.8; Node-only steps use runner Node. Record actual runtime Node/version evidence rather than claiming a nonexistent configurable quality input. Gates.yml and local sweep/updater have supported Node version knobs/pins as listed above.

Doctor CLI supports `doctor [path] --json --offline` and optional `--readiness`. **Ordinary doctor is not read-only:** `src/cli/doctor.ts` checkInstructionFiles calls migrateInstructionFiles and normalizes AGENTS/CLAUDE. `--readiness` also persists .lisa/readiness.json. Neither was executed in this research lane. Use a disposable consumer checkout for baseline doctor reproduction and controlled implementation checkout for final proof. Save attributable generated diffs rather than restoring unrelated edits.

Worker qualification is an explicit precondition, not activation permission. `.lisa/worker-config.json` may contain workers or agents as an array/object. The matched entry requires host, modelId/model, version, qualificationEvidence/evidence. Doctor reads the runtime signature from explicit LISA_WORKER_* or current runtime identifiers, compares model/version and reports absent evidence or drift as warning. Representative journeys and current-host/version evidence must qualify a worker before unattended factory runs. Never invent model identities or change settings to make a record match. Deterministic CI/sweeps do not establish autonomous worker qualification.

Sources: [doctor command](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/src/cli/index.ts), [doctor normalization](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/src/cli/doctor.ts), [epoch check](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/src/cli/doctor-worker-epoch.ts), [epoch fields](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/src/cli/doctor-worker-journey.ts).

## Reproduction and future verification commands

These are future commands, not results from this research stage. Use an isolated disposable checkout for commands that may write. Normal installation/apply remains deferred until published upstream fixes and the parent's reviewed integration decision.

```sh
# Live identity (read only)
PATH=/Users/cody/.local/share/mise/installs/node/22.21.1/bin:$PATH npm view @codyswann/lisa version gitHead lisaReleaseCommit lisaReleaseTag dist.integrity engines --json
gh api repos/CodySwannGT/lisa/commits/v4.68.0 --jq .sha

# Baseline and final doctor in disposable/explicit implementation checkout
node node_modules/@codyswann/lisa/dist/index.js doctor . --json --offline
# Optional worker readiness is separate, writes its own report
node node_modules/@codyswann/lisa/dist/index.js doctor . --json --offline --readiness

# Exact contract/gate checks after managed prerequisites are actually installed
node scripts/lisa-work-item.mjs contract-version
node scripts/lisa-gates.mjs validate
node scripts/lisa-gates.mjs list --moment=pull-request
node scripts/lisa-gates.mjs contexts --moment=pull-request
node scripts/check-third-party-action-pins.mjs --root . --json
node scripts/check-threshold-ratchet.mjs --base origin/main

# Real Rails proof, isolated synthetic MySQL8.4 after test safety prerequisites
PRIMARY_DB_HOST=127.0.0.1 RAILS_ENV=test bin/rails db:prepare
PRIMARY_DB_HOST=127.0.0.1 RAILS_ENV=test bash scripts/lisa-scratch-run.sh --suite rspec-mysql -- bundle exec rspec
bundle exec rubocop
bundle exec reek app/ lib/
bundle exec flog --all --group app/ lib/
bundle exec flay app/ lib/
bundle exec brakeman --no-pager --quiet
bundle exec bundler-audit check --update

# Actual delivery stage readback, not executable permission for this stage
gh pr checks <PR> --repo CodySwannGT/railsstarter
gh api repos/CodySwannGT/railsstarter/actions/runs/<RUN> --jq '{event,head_sha,status,conclusion,referenced_workflows}'
gh api --paginate 'repos/CodySwannGT/railsstarter/actions/runs/<RUN>/jobs?per_page=100' --jq '.jobs[]|{name,status,conclusion}'
gh api --paginate 'repos/CodySwannGT/railsstarter/commits/<HEAD>/check-runs?per_page=100' --jq '.check_runs[]|{name,head_sha,status,conclusion,details_url}'
# Only after authorized delivery/default-main merge and actual elapsed schedule:
# Resolve GitHub auth through the project GitHub access layer first, without printing it
node scripts/check-workflow-load-failures.mjs
```

Do not substitute quality static source inspection for actual PR/head CI. Match run event/head SHA, actual reusable SHA, populated job list, final conclusions, every enforced context and meaningful nonzero RSpec example count. Check traceability log shows validation, not unenforceable skip. Use a disposable threshold weakening fixture to demonstrate ratchet rejection and missing-supervisor fixture to demonstrate fail-closed behavior, without changing thresholds or guards in the real consumer. Retained schedules require actual schedule-event runs on default main after merge. Dispatch can demonstrate load/runtime first but is not schedule-event proof.

## Cross-issue order and bounded implementation handoff

1. Parent obtains separately reviewed commits from #63 and #61, preserving each lane's trailer/binding and ownership. #63 gems must reach the relevant candidate tree before advisory gates can pass. Meaningful-suite proof must use separately reviewed #69 commits or real bounded specs selected by the parent, rather than assuming #61 supplies examples. #61 construction and safety scripts remain separately owned prerequisites where applicable, with no source import without the parent’s reviewed integration decision. These local lanes are not shipping artifacts merely because their work is reviewed.
2. Verify upstream #4334 initializer correction and #4335 active-hook continuity merge/release/registry, if choosing full managed adoption. Current4.68 does not contain those corrections. Never patch an overwritten generated initializer or suppress RuboCop to unblock the workflow. Do not run full apply in this active session before continuity is safe.
3. Under the parent's **separate reviewed integration decision**, implement the narrowly owned #65 workflow/config/script delta from published source. Do not copy root's entire dirty managed upgrade, root #61 source or #63 working files. Preserve exact leaf commits through sanctioned integration and keep every permanent PR target main. Temporary integration feature branches, if needed, remain ordinary disposable features.
4. The prerequisite cycle means an isolated baseline #65 cannot be called delivered by a zero-example pass, and isolated #63/#61/#69 cannot claim current baseline CI passes without #65 wiring. Parent should choose a reviewed combined candidate/stacking order with scoped commits and tracker linkage, then prove the actual main-target PR tree. This specialist does not invent that integration decision or mutate bindings.
5. Prove local gates, fresh actual PR checks and default-main retained schedule events. Declare disabled deployment from actual workflow surface, no AWS runtime proof or fake target. Only later parent lifecycle owns merge, terminal closure and all-issue progress.

No truly missing required access remains in this research scope. Remaining information is coordination rather than user ambiguity: parent's reviewed integration commit selection, release identity of upstream fixes once published, and the deliberately retained scheduled population. These can be resolved during implementation planning without asking again about main-only topology.

## Dated final publication refresh: 2026-10-04 UTC / October3 local

Registry latest changed during the bounded research stage to **4.68.1**. Final current identity is package/version4.68.1, tagv4.68.1, gitHead/lisaReleaseCommit **d58ad3182285c14e174f430045b385a678a07bcd**. GitHub v4.68.1 resolves to that same commit, dated2026-10-04T02:12:13Z. Registry integrity is `sha512-qYd2JLLiqJIz+xdCO+l8v3wyrP30rPHMb0NAtvzijbyChPhzby3o13jlDd19XkDUK3e4POVikSAdAY/JRB3UZQ==`. These facts supersede the initial4.68.0 latest-release observation above without turning source inspection into adoption.

The4.68.1 npm cache request was absent (ENOENT), a resolvable retrieval prerequisite. Private ranged GETs downloaded **13,883,656 bytes**, reassembled and verified the full SHA512 against the live registry. Extraction stayed under `/var/folders/_2/29n6gy1s42777swvq24j3fh00000gn/T/railsstarter-65-upstream-4681-edie7vpb/package`, without install, lifecycle execution, shared cache writes or project apply. Packed package stamp and engines exactly match registry: Node22.21.1, Bun1.3.8 unchanged.

Publication and source inclusion are independently supported, rather than inferred only from ancestry:

- [PR4339](https://github.com/CodySwannGT/lisa/pull/4339) is MERGED at2026-10-04T02:10:19Z, original leaf commit `7f18ea60083e2f94ed5c1a2dcb5bbe790dbad954`, merge commit `7963047441dd77a08dd31e5b2606e3890ed00f5f`.
- [Release and Deploy37170229473](https://github.com/CodySwannGT/lisa/actions/runs/37170229473), attempt1, eventpush, exact merge head7963047…, completed/success. Paginated jobs include **Publish to npm / Publish to npm**, job111341956650, completed/success. Other release jobs have their actual success/skip results; no claim that each release step ran is made.
- [Official compare4.68.0→4.68.1](https://github.com/CodySwannGT/lisa/compare/728d35afbd3de4d522023e0b65fd0f730c94820c...d58ad3182285c14e174f430045b385a678a07bcd) contains the#4334 initializer correction, its merge and release. The **actual integrity-verified packed template** now has the blank line after frozen_string_literal and preserves `APP_VERSION = Rails.root.join('VERSION').read.strip.freeze`.
- Packed comparison against4.68.0: exactly one of41 Rails files differs, `rails/copy-overwrite/config/initializers/version.rb`. All840 dist/cli files, all69 dist/codex files, project-config reader/type schema, release/consumer pinner, deletion guard, config-resolution reference, lisa-work-item, lisa-gates and third-party-pin checker are byte-identical. The official quality-rails.yml contents GET atd58… is byte-identical to728….

Therefore **#4334 is published in4.68.1**, while **#4335 active-hook continuity is absent from4.68.1**. Do not require a further unpublished#4334 fix, and do not treat this initializer-only release as solving the hook boundary. Full apply remains deferred until a released#4335 correction and the parent's reviewed integration decision. Current coherent adoption pair, if4.68.1 is chosen, is package4.68.1 plus reusable SHA `d58ad3182285c14e174f430045b385a678a07bcd # v4.68.1`; refresh before actual implementation because publication is active.

No quality/gates/schema/doctor/deployment-enable interface changed. There is still no supported deploy.enabled/disabled boolean; actual disabled delivery requires reviewed host-owned executable workflow retirement, with no fake success job or inaccessible target. Ordinary doctor still normalizes instruction files. Third-party checker dependency closure should explicitly include both `scripts/lib/invoked-as-script.mjs` **and `scripts/lib/bounded-spawn.mjs`**, whose imports are Node built-ins.

Coordinator artifact review found no material schema/pin/disabled-deployment mismatch beyond the temporal release update. The aggregate research/plan must mark4.68.1 current, #4334 published and only#4335 still absent, and should name bounded-spawn in the chosen pin-checker closure. Meaningful-suite prerequisite is corrected to separately reviewed#69 commits/real parent-selected bounded specs, never assumed#61 source import.
