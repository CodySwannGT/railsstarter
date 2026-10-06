# CI/workflow migration research: CodySwannGT/railsstarter#65

Outcome: roster and research complete; implementation and delivery have not started. This is the research stage inside Lisa Implement, not a new PRD/ticket flow. Findings were collected October 3, 2026 local time (October 4 UTC for some probes). No passing delivery verdict is asserted.

Final publication refresh at2026-10-04T02:58:22Z: registry latest advanced to **4.68.1**, gitHead/lisaReleaseCommit `d58ad3182285c14e174f430045b385a678a07bcd`, tagv4.68.1, integrity `sha512-qYd2JLLiqJIz+xdCO+l8v3wyrP30rPHMb0NAtvzijbyChPhzby3o13jlDd19XkDUK3e4POVikSAdAY/JRB3UZQ==`. #4334's [PR4339](https://github.com/CodySwannGT/lisa/pull/4339) merged at02:10:19Z, merge `7963047441dd77a08dd31e5b2606e3890ed00f5f`; [Release and Deploy37170229473](https://github.com/CodySwannGT/lisa/actions/runs/37170229473) attempt1 completed success. Its npm job111341956650 shows immutable identity validation/stamping, OIDC publication and registry verification all success. Release commit descends from that merge. #4335 still has no linked PR in exhausted current reads. Installed consumer remains4.67.0 and nothing was applied. The detailed4.68.0 comparison below is retained as dated evidence; it is not the latest-version claim. Full new-package/interface confirmation is recorded in the upstream specialist artifact and final refresh note below.

Final4.68.1 packed-source proof: private13,883,656-byte download matched that live SHA512; extracted without install/lifecycle or shared-cache writes. Exactly one of41 Rails files changed from4.68.0: `rails/copy-overwrite/config/initializers/version.rb` gains the required blank line after its magic comment. All840 dist/cli files,69 dist/codex files, reviewed config/pinner/deletion contracts and work-item/gates/action-pin scripts are byte-identical. Official quality-rails source atd58ad318 is byte-identical to728d35af. Thus current published interface/toolchain/disabled-deploy findings below remain valid at **4.68.1**; use the new release-stamped SHA for its consumer calls. #4334 has packed-artifact inclusion, while #4335 active-hook continuity remains absent. No consumer adoption is claimed. Private extraction path and complete comparison are in upstream research. The separate Lisa Update run37170744046 failure is not a failed publication of4.68.1.

## Identity, instructions and evidence boundary

- Canonical ref: `CodySwannGT/railsstarter#65`; existing verified claim is retained. No claim, tracker body/comment, hold history or trusted-human policy was changed in this stage.
- Actual worktree: `/Users/cody/workspace/railsstarter/.claude/worktrees/65-ci-workflow-migration`; feature `codex/65-ci-workflow-migration`; base and future PR target `main`. Live main readback was `31517fd9aa0c4baf3e5eaecc3d9f7b4c5f271a44`, also current HEAD. Refresh immediately before implementation.
- Exact `lisa-work-item.mjs current` readback: version 1, github, ref above, branch above. Machine binding lives under the existing common Git directory's `worktrees/65-ci-workflow-migration/lisa/work-item.json`. Never replace another worktree's binding.
- Complete ignored input: `.lisa/work-item-context.md`, 1,419,624 bytes, SHA256 `ed968c929a4b7f0c32d610aab6f36794493b697a9bada131f1a48794f5838daa`. Resolver resolution remains ignored at `.lisa/work-item-resolution.json`. Source bundle contains 28 unique issues, 36 unique comments and 168 exhausted pagination surfaces. All three JSON sections and complete comment inventory were read. Do not copy raw bundles or credential-bearing logs into these trackable documents.
- Historical hold comment 5970058812/body remain historical. Automation authorization comment 5974206797 records this session's authorization honestly; claim comment 5974207778 is not completion or trusted-human approval. No impersonation or `trustedHumanActorIds` change.
- Read current AGENTS, `.claude/rules/PROJECT_RULES.md`, wiki start/index/schema contract, installed Implement gates and applicable access/verification rules. `.agents/rules` is absent in this isolated baseline. Wiki resolver succeeds with a current local wiki; its index has orientation/staff, not a CI migration synthesis. No raw learning ledger was loaded: configured local ledger is absent; only bounded executable projection is permitted if one appears.
- Main is the only permanent remote integration branch. Ignored `.lisa.config.local.json` contains exactly `{"deploy":{"branches":{"dev":"main"}}}`. This is a validator environment mapping, not permission to create dev/staging. Historical project staging prose is superseded by the explicit current user instruction.

The actual ten-type native catalog and one include/exclude reason per type were recorded before researchers were created in [the per-issue roster](roster/CodySwannGT-railsstarter-65.md). Included explorer is the required read-only research equivalent; included default supplies bounded upstream/acceptance roles unavailable as native named specialist dispatch. No model/safety override was used. Three separate agents own [local](research/CodySwannGT-railsstarter-65-local.md), [upstream](research/CodySwannGT-railsstarter-65-upstream.md) and [acceptance/access](research/CodySwannGT-railsstarter-65-acceptance.md) research. Their full bounded task prompts and sanitized comment inventory are alongside them. Root/parent is not directly addressable in this session, so findings return through this handoff under the documented nested Codex fallback.

## Empirical diagnosis and access

The existing scheduled run [34953782826](https://github.com/CodySwannGT/railsstarter/actions/runs/34953782826) is completed/failure at the baseline SHA and has zero jobs. Five callers reference missing retired reusable workflows. Current `ci.yml` calls mutable quality-rails@main, whose test/ratchet jobs require absent supervisor/comparator scripts. A historical green PR is not proof for the future #65 candidate.

| Surface and cheapest documented probe | Current observed result | Practical limit |
| --- | --- | --- |
| GitHub repo/source: `gh api repos/CodySwannGT/railsstarter`; immutable Lisa contents GET | Authenticated reads succeed; main default; reported pull/push/admin/maintain/triage permissions true | No write/dispatch tested or performed |
| Actions/rulesets/checks: scoped API GETs with exhausted pagination | Actions enabled; allowed_actions all; sha_pinning_required false; active required rulesets readable | Classic protection 404 is not missing access; active rulesets still enforce gates |
| Workflow/run/job inventory: paginated Actions GETs | Nine workflows; three old nightlies disabled_inactivity; failed baseline schedule has zero jobs | No future PR/runtime success asserted |
| Registry/source: explicit installed Node/npm `view @codyswann/lisa ... --json`, tarball HEAD, full tarball integrity | Initial4.68.0 cached13,883,639-byte integrity pass; final4.68.1 privately downloaded13,883,656-byte integrity pass plus merged/published identity above | Shared installed package remains4.67.0; neither publication nor packed-source proof equals consumer adoption |
| Node/Bun/npm: explicit documented mise installation paths `--version` | Node22.22.0 access probe; supported Node22.21.1 also available; Bun1.3.8; npm10.9.4 | Bare node/npm absent PATH and local mise trust refusal are resolvable setup routing, not missing credentials |
| Ruby/Bundler: from `/Users/cody`, `mise exec ruby@3.4.8 -- ruby --version` / `bundle --version`; `BUNDLE_GEMFILE=<this worktree>/Gemfile bundle check` | Ruby3.4.8, Bundler2.6.9; dependencies satisfied | Lock records2.4.10; raw bundle route selects it. Record actual route; no audit/boot proof |
| Advisory source: `git ls-remote https://github.com/rubysec/ruby-advisory-db.git HEAD` | Reachable HEAD97659622944c19d42961c03813666f4196457229 | Reachability does not clear #63 audit findings |
| Docker: version; `docker image inspect mysql:8.4` | Client/server29.2.1; existing image sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242 | No isolated database started or queried; later setup prerequisite |
| Secret/variable metadata only | DEPLOY_KEY name; ENABLE_CLAUDE_NIGHTLY name | No values read/stored; no worker intent inferred; no optional scan auth claim |

No truly missing required access was found. No secrets were printed or persisted. Services not yet installed/started remain setup prerequisites. Live AWS deployment is outside the starter's authored disabled-deployment journey; synthetic Rails test SDK stubs are appropriate for that journey and do not prove live AWS access. Optional FOSSA/GitGuardian API steps do not prove the separately required external GitGuardian app status. SonarCloud is not an authored or current ruleset requirement; if a future retained feature makes it required, exhaust the documented resolver sources and perform its authenticated read before dependent work. A real later access failure must name the exact resource/probe and stop dependent work, not receive a weaker substitute.

One diagnostic was not purely read-only: installed4.67 `doctor . --json --offline` exited1 and appended22 managed AGENTS lines through `checkInstructionFiles -> migrateInstructionFiles`. The coordinator proved the original bytes plus only that suffix, removed only the attributable suffix, and verified exact stage-start AGENTS SHA256 `fb44c4ad8adbd0e998c63c8ed44a87edc71af993011f3df4a2ed84671de155ef`. [Incident/restoration evidence](research/CodySwannGT-railsstarter-65-doctor-side-effect.md) is retained. Future doctor reproduction belongs in a disposable complete clone/snapshot; final doctor belongs in the reviewed implementation lane with before/after status. `--readiness` additionally writes a report. Preserved `.claude/settings.json` startup plugin-key migration was untouched.

Doctor baseline findings: absent apply receipt/enforcement artifacts, undeclared traceability, mutable reusable refs, missing scratch/threshold coupling and unstated deploy intent. Offline branch/ruleset uncertainty was resolved separately with GitHub reads. Do not call it a passing gate or bypass its substantive findings.

## Published identity, pins and exact reusable interfaces

Installed4.67.0 gitHead/tag commit: `4bb326e655301ad1188a57583b804fc03fe29003`. Initially researched published4.68.0 tag/release stamp/gitHead: `728d35afbd3de4d522023e0b65fd0f730c94820c`; registry integrity `sha512-0O+qO+g6psWj5J1hX9N743t7MhQjeM0w0vYgLFVXCGED4TCdVVWa13bJlDnl63hqzapi/6Wdhlw0ljqTU9qflA==`. Its41 Rails artifacts and reviewed config/doctor/pinner/deletion contracts match installed4.67 and exclude both then-pending fixes. Final published4.68.1 includes #4334's merged initializer correction; #4335 remains pending. Re-read publication before implementation; do not apply an unreleased checkout and call it published adoption.

Use the package's release-stamped immutable reusable SHA, not raw template @main. Official [pinner](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/src/core/reusable-workflow-pin.ts) fails closed on invalid/missing stamps. Preserve required third-party action SHA/version comments under the actual [detector policy](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/all/copy-overwrite/scripts/check-third-party-action-pins.mjs); GitHub org exceptions do not justify mutable Lisa reusable refs.

Primary current interface: [quality-rails.yml at4.68.1](https://github.com/CodySwannGT/lisa/blob/d58ad3182285c14e174f430045b385a678a07bcd/.github/workflows/quality-rails.yml), byte-identical to the initially researched4.68.0 definition. No outputs. Exact inputs:

| Input | Type/default | Planned caller value |
| --- | --- | --- |
| expected_workflow_contract_major | string / empty | `'1'` |
| database_type | string / postgres | `mysql` |
| database_name | string / test | `railsdb` synthetic test base, matched to four test connections |
| database_version | string / empty (MySQL fallback8.0) | `'8.4'` |
| expected_work_item_contract | string /1.1.0 | `'1.1.0'` matching actual validator |
| skip_jobs | string / empty | Empty; no exemptions |

Caller floor: contents:read, checks:write, pull-requests:write, issues:read. Caller job name stays `Quality Checks` to preserve required contexts. Optional secrets: GITGUARDIAN_API_KEY, FOSSA_API_KEY, JIRA_API_TOKEN, JIRA_LOGIN, LINEAR_API_KEY. Github tracker uses the run token; no Jira/Linear need. Quality exposes no Node/Bun/Ruby version input. Ruby follows `.ruby-version`; learnings selects Bun1.3.8; record actual runner Node rather than inventing an input. Local/package pin recommendation Node22.21.1, Bun1.3.8; preserve Ruby3.4.8 unless separately coordinated #64 change.

Actual MySQL route: db:prepare, then `bash scripts/lisa-scratch-run.sh --suite rspec-mysql -- bundle exec rspec`. Threshold route requires comparator plus both imports and real origin/base. Traceability1.1.0 must actually validate PR range/backlinks, not succeed through absent-config skip. MySQL schema does not execute the PostgreSQL-specific mutation job; that inherent interface limit must be reported, not obscured with new skip tokens. Lint, Code Quality, Security, threshold, structural/learnings and real test routes stay enforced.

Secondary researched interface [gates.yml](https://github.com/CodySwannGT/lisa/blob/d58ad3182285c14e174f430045b385a678a07bcd/.github/workflows/gates.yml): `moment` required string; optional expected_workflow_contract_major(string empty), node_version(string22.21.1), package_manager(string npm), working_directory(string empty), install_dependencies(boolean true), timeout_minutes(number60), ref(string empty); contents:read; no outputs/secrets. It is a deterministic declared-gate facade, not a replacement code-improvement worker. A continuous seed needs nonempty real provers and no fictional production target. This plan does not add it merely to produce a green schedule.

Official local scheduled seeds were researched, not adopted/activated: workflow-load-failure-sweep requires Node22.21.1, gh, actions:read/contents:read, detector/imports and fails on uncovered26-hour windows/20-page-cap; lisa-update requires a real LISA_UPDATE_TOKEN PAT and creates issues/commits/PRs. Neither replaces autonomous test-authoring/complexity/review-response semantics. Default plan retires the obsolete schedules without adding workers. Any later deliberately retained schedule needs real default-main event proof and epoch qualification before unattended workers; qualification is not activation permission.

## Exact affected files and retirement rationale

The proposed implementation manifest is bounded to the files below. Parent separately selects published managed-adoption ownership; no whole dirty root upgrade is permitted. [Rails deletion manifest](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/rails/deletions.json) marks the five old files `basis: needs-review`, not automatic permission. Actual baseline ownership classifier only recognizes ci as Lisa-managed; legacy seeded prose is not a canonical ownership header. Do not forge headers to justify deletion.

| Path | Proposed action and preserved purpose |
| --- | --- |
| `.github/workflows/ci.yml` | Supported host-owned quality caller, immutable package-compatible SHA, explicit contracts/MySQL8.4/permissions, original required context names |
| `.github/workflows/claude-code-review-response.yml` | Reviewed retirement of missing callee; remediation continues through reviewed PR workflow/required CodeRabbit, without claiming equivalent autonomous response |
| `.github/workflows/claude-nightly-code-complexity.yml` | Reviewed retirement; actual complexity enforcement remains in PR Code Quality; improvement through reviewed issue work |
| `.github/workflows/claude-nightly-test-coverage.yml` | Reviewed retirement; meaningful RSpec/coverage enforcement remains; no substitute automatic test-writing claim |
| `.github/workflows/claude-nightly-test-improvement.yml` | Reviewed retirement; test maintenance remains reviewed issue work; no non-equivalent dependency scan rename |
| `.github/workflows/claude-sync-down-branches.yml` | Remove obsolete main→staging→dev topology; main-only rationale |
| `.github/workflows/deploy.yml` | Reviewed executable caller retirement, durable no-target intent/enabling prerequisites; coordinate #61/#74 ownership |
| `.github/workflows/validate-pull-request.yml` | Review standalone RuboCop/Sonar overlap. Preserve during initial wiring; remove only after actual required-context parity and a reviewed disposition. Sonar is optional, not a required-context substitute |
| `.lisa.config.json` | Supported truthful traceability/gate declarations/topology; preserve trust policy and required checks; do not invent deployment keys |
| `package.json`, existing `package-lock.json`; `bun.lock` only in explicitly scoped Bun adoption | Published Lisa dependency/lock selection, actual check:work-item and companion validate-push commands; isolate postinstall behavior during approved install. Current baseline uses package-lock.json; do not silently introduce inconsistent parallel lockfiles or take #85 broad adoption ownership |
| `.mise.toml` | Supported Node22.21.1/Bun1.3.8 local pins alongside existing Ruby; no model/safety edits |
| `scripts/lisa-scratch-run.sh` | Published Rails supervisor; preserve authority/cleanup/failure propagation |
| `scripts/check-threshold-ratchet.mjs`, `scripts/threshold-ratchet-families.mjs`, `scripts/threshold-ratchet-compare.mjs` | Complete published Rails ratchet bundle; no weakening/exemptions |
| `scripts/lisa-work-item.mjs`, `scripts/lib/invoked-as-script.mjs` | Real tracked official validator/import, replacing only this lane's temporary ignored helper links through reviewed adoption; binding unchanged |
| `scripts/lisa-gates.mjs`, `scripts/check-third-party-action-pins.mjs`, `scripts/lib/bounded-spawn.mjs` | Published universal gate/pin checks if selected in scoped managed adoption; pin-checker closure explicitly includes bounded-spawn and invoked-as-script |
| Per-issue roster/research/plan and scoped workflow migration documentation | Durable dispositions, future enabling prerequisites, exact proof/handoff |

Any further hook/guard/receipt/managed file required by the approved adoption must be enumerated from its normal staged diff and given separate ownership before inclusion. This list does not authorize blanket copying. Preserve `.ruby-version`, Gemfile/lock ownership#63, #61 construction/verification source, coverage/security thresholds, secret sources, shared images/caches and `.claude/settings.json` startup migration. Meaningful-suite source belongs to #69 or separately reviewed explicit fixtures; it is a dependency, not silently #65-owned app work.

No supported `deploy.enabled`/`deploy.disabled` boolean exists in reviewed4.67/4.68 schema/executable/docs. Unknown-key round-trip preservation is not functionality. Official [deploy-intent doctor](https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/src/cli/doctor-rails-deploy-intent.ts) accepts absent deploy.yml. Commented-main explanation only withholds automatic production while workflow_dispatch remains executable. Therefore remove the executable caller with honest durable intent, inspect all retained triggers/callees for alternate deploy paths, and preserve separately owned #61 construction files. Do not obtain unused AWS targets or add success stubs.

## Complete acceptance matrix

All implementation/runtime outcomes below are PENDING. Completed research resolves the design, not these delivery gates. Labels split the authored requirements into independently provable atoms.

| Atom | Required result | Proof at the actual candidate boundary |
| --- | --- | --- |
| AC1a | No retired/missing callable workflow | Explicit dispositions; every retained callee GET at immutable revision succeeds; disposable doctor and fresh run load real jobs |
| AC1b | Scratch/threshold dependencies shipped | Tracked complete bundle; real PR supervisor/test and comparator execute; missing-supervisor fixture fails closed |
| AC1c | Declared/executable traceability agrees | Actual contract1.1.0 and check:work-item; complete PR base..head mapping/backlinks validates; undeclared or missing mapping fails |
| AC1d | Supported visible disabled deployment | Absent executable deploy caller accepted by doctor; retained trigger/callee inventory contains no release/deploy route; no stub or live-target claim |
| AC1e | Honest ownership/retirement semantics | Canonical header/classifier readback; explicit host review of needs-review/unattributable deletion; no fabricated header |
| AC2a | Fresh PR main loads populated workflow | Exact PR/run/attempt/merge-or-head identity; immutable referenced_workflows; nonzero intended jobs/steps; no startup schema/permissions error |
| AC2b | Required and authored gates truly pass | Five current app/context identities terminal success plus actual traceability/threshold/MySQL named examples, not skips/zero pass |
| AC2c | Any retained schedule runs on default main | Default plan retains no autonomous schedules: prove each old retirement on main. If parent deliberately retains one, actual event=schedule after merge, real entrypoint/nonzero jobs/results are mandatory |
| AC2d | Main-only remote topology | Exhaust branch pagination before/after; no dev/staging created; all feature PR bases main; sync route removed |
| C1 | Published adoption claims accurate | Necessary upstream PR merge + terminal publication + registry version/integrity/release stamp + consumer readback;4.68.1's #4334 release and pending #4335 boundaries acknowledged |
| C2 | Local mapping/binding preserved | Ignored local dev:main only; exact current readback; no unrelated binding change |
| C3 | Meaningful nonzero examples and intact coverage | Named real request/contract examples local and actual PR CI; count>0; deliberately empty discovery exits nonzero;80/70 enforcement aligns without lowered thresholds |
| C4 | Context/hold/authorization/trust history preserved | Unedited ignored input hash; no claim/history rewrite or trustedHumanActorIds change; stage-accurate evidence |
| C5 | Scoped concurrent integration | Original dependency commit SHAs/trailers and per-lane bindings preserved; reviewed minimal integration; no #61 dirty transplant or whole managed upgrade |
| C6 | Auditable actual roster and independent verdict | Per-issue roster before dispatch; later independent verifier references exact artifact/run/evidence in v2 verdict, not self-certification |

Current required contexts: Actions app15368 `Quality Checks / Lint`, `Quality Checks / Code Quality`, `Quality Checks / Security` (ruleset18805283); CodeRabbit app347564 `CodeRabbit` and GitGuardian app46505 `GitGuardian Security Checks` (ruleset18805433). Only merge method `merge`, review-thread resolution required. Bypass actor existence is not permission to bypass. Threshold/test/traceability remain required by this task even where rulesets do not list them. Refresh rules immediately before delivery.

Baseline has only RSpec helpers, no *_spec.rb; `.simplecov`0/0 disagrees with declared80/70. No zero-example green is valid. Separately reviewed #69 suite/nonzero guard (or explicitly owned bounded real regression fixtures) must reach the candidate. Real `/` and `/up` requests with synthetic SDK fixtures are meaningful candidates. Workflow migration regression fixtures cover missing caller/script, contract/permissions loading, undeclared traceability and absent-deploy intent. Static fixtures complement actual GitHub runtime proof; they cannot replace it.

## Reproduction and verification commands

Read-only baseline reproduction (already observed):

```sh
gh api repos/CodySwannGT/railsstarter/actions/runs/34953782826 --jq '{id,event,head_sha,status,conclusion,html_url}'
gh api --paginate 'repos/CodySwannGT/railsstarter/actions/runs/34953782826/jobs?per_page=100' --jq '{total_count,jobs:[.jobs[]|{name,status,conclusion}]}'
/Users/cody/.local/share/mise/installs/node/22.22.0/bin/node scripts/lisa-work-item.mjs current
git check-ignore -v .lisa/work-item-context.md .lisa/work-item-resolution.json .lisa.config.local.json
```

Future commands only, after separately authorized scoped adoption and isolated test DB setup; doctor writes instruction normalization and needs disposable/reviewed lane:

```sh
node node_modules/@codyswann/lisa/dist/index.js doctor . --json --offline
node scripts/lisa-work-item.mjs contract-version
node scripts/lisa-work-item.mjs current
node scripts/lisa-gates.mjs validate
node scripts/lisa-gates.mjs list --moment=pull-request
node scripts/lisa-gates.mjs contexts --moment=pull-request
node scripts/check-third-party-action-pins.mjs --root . --json
node scripts/check-threshold-ratchet.mjs --base origin/main
npm run check:work-item -- --base "$PR_BASE_SHA" --head "$PR_SHA" --repo CodySwannGT/railsstarter --pr-number "$PR_NUMBER"
bundle exec rubocop
bundle exec reek app/ lib/
bundle exec flog --all --group app/ lib/
bundle exec flay app/ lib/
bundle exec brakeman --no-pager --quiet
bundle exec bundler-audit check --update
PRIMARY_DB_HOST=127.0.0.1 RAILS_ENV=test bin/rails db:prepare
PRIMARY_DB_HOST=127.0.0.1 RAILS_ENV=test bash scripts/lisa-scratch-run.sh --suite rspec-mysql -- bundle exec rspec --format documentation
```

Commands assume selected tools on PATH without changing trust/model/safety settings, plus DATABASE_NAME/DATABASE_PORT routed to a uniquely isolated MySQL8.4 service. Prove primary/queue/cache/cable test identities before db:prepare; respect #62 safety guards and #67 AWS-free boot scope. A failed setup is fixable, not authorization to use another lane's service or weaken audit/coverage. Empty-suite and threshold-weakening negative fixtures execute only in disposable fixtures with independent expected failures.

Future actual PR proof, no PR created here:

```sh
gh pr view "$PR_NUMBER" --repo CodySwannGT/railsstarter --json number,url,baseRefName,headRefName,headRefOid,statusCheckRollup,commits
gh api "repos/CodySwannGT/railsstarter/pulls/$PR_NUMBER" --jq '{number,state,merged,base_ref:.base.ref,base_sha:.base.sha,head_ref:.head.ref,head_sha:.head.sha,merge_commit_sha}'
gh api --paginate "repos/CodySwannGT/railsstarter/actions/runs?event=pull_request&branch=codex/65-ci-workflow-migration&per_page=100"
gh api "repos/CodySwannGT/railsstarter/actions/runs/$RUN_ID"
gh api --paginate --slurp "repos/CodySwannGT/railsstarter/actions/runs/$RUN_ID/attempts/$ATTEMPT/jobs?per_page=100"
gh api --paginate "repos/CodySwannGT/railsstarter/commits/$PR_SHA/check-runs?per_page=100"
gh api --paginate "repos/CodySwannGT/railsstarter/commits/$PR_SHA/statuses?per_page=100"
gh run view "$RUN_ID" --repo CodySwannGT/railsstarter --attempt "$ATTEMPT" --log
```

Set variables only from fresh provider readback. Require PR base main/head feature, tie returned PR head SHA and run head/merge artifact explicitly, capture exact attempt and referenced reusable SHA; do not reject valid tested merge artifacts solely because they differ from the source head or accept unrelated runs by branch name. Exhaust jobs/check/status pagination, compare app identities/names against live rulesets, retain sanitized named-example/count/coverage/validator/ratchet evidence. [GitHub proof note](research/CodySwannGT-railsstarter-65-github-proof.md) links primary docs and specifies these boundaries. Schedule and dispatch definitions depend on default branch; a PR run cannot prove an actual scheduled event. Future retained schedule proof requires real event=schedule on main containing the merged candidate; no schedules retained means honest removal evidence, not a fabricated schedule pass.

## Integration/order conclusion

#63's normally committed Gemfile/lock patch is needed by bundle audit; #63 delivery needs #65 CI. Resolve the cycle with a parent-reviewed dependent feature candidate: preserve original #63 commit SHA/trailer, merge that committed dependency into #65 only after the parent's separate integration decision, keep #65 binding, and target main. Do the same only for explicitly reviewed meaningful-suite prerequisite commits. Each commit names its own canonical Work-Item; the joint PR declares every actual range reference on separate lines with non-closing issue references and proven backlinks. Contract1.1.0 compares declared PR references against the complete base..head commit mapping, not just the bound leaf. Never rebind #65 to #63 or copy #63 uncommitted files. Prefer ancestry-preserving integration/merge over duplicate cherry-picks where maintaining original leaf commits is required.

Do not import #61 construction/verification files into #65 without a separate reviewed parent decision. #61 can refresh onto supported main after shared candidate delivery, retaining its own source/commit identity. Coordinate deploy caller overlap with #61/#74 while leaving construction artifacts intact. #69 supplies meaningful suite/nonzero behavior; #62/#67/#71/#64/#85/#86 retain their distinct safety/boot/database/Ruby/adoption/initializer scopes. Necessary fixes may be committed prerequisites, not convenient exclusions.

Before full apply, require actual published inclusion of #4334 initializer and #4335 active-hook continuity fixes, plus normal consumer version/receipt readback. Published4.68.1 advances #4334's upstream release prerequisite; #4335 remains pending and no consumer adoption was performed. Parent chooses a reviewed common managed-adoption commit and ownership; #65 then takes only supported CI/declaration/script scope. No root dirty upgrade is copied. Refresh main and all temporal publication/commit/provider facts before build. No permanent integration branch beyond main.

No new user product clarification or credential request is necessary. Remaining items are ordinary parent integration decisions and executable build/delivery prerequisites. The implementation plan is [the canonical per-issue plan](plan-CodySwannGT-railsstarter-65.md). #65 and the parent all-open-issue goal remain incomplete.

## Research handoff verification

Independent acceptance reviewer found all authored requirements/comment constraints represented and no false implementation completion or dispatch. Its concrete corrections are applied: REST PR base/head read, legacy commit statuses, attempt-specific logs and supported task/verification/access metadata vocabulary. Independent upstream reviewer validated interfaces/pins/disabled-deployment semantics and requested the final4.68.1 publication boundary plus explicit bounded-spawn import; both are applied. Detailed reviewer results remain in their exclusive artifacts. These reviews certify the research/plan content, not runtime acceptance.

Documentation verification: complete10-type roster with research included; all five proposed tasks expand to required metadata; valid JSON/enums; local artifact links resolve; canonical documents have no trailing whitespace. Final status/hash/binding checks preserve the input and show only the preexisting startup settings change plus trackable per-issue documents. AGENTS restoration matches stage-start exactly. No commit/push/PR/merge/closure, new tickets, claim repetition, worker enablement, install or full apply occurred. The diagnostic side effect is disclosed above rather than hidden.
