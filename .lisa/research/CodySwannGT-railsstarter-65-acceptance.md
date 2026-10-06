# #65 acceptance, access and integration research

Stage: bounded research only. Observed 2026-10-04T01:52:15Z onward. Canonical leaf: `CodySwannGT/railsstarter#65`. Worktree: `/Users/cody/workspace/railsstarter/.claude/worktrees/65-ci-workflow-migration`. Branch: `codex/65-ci-workflow-migration`. Base/PR target: `main`. Resolver base SHA: `31517fd9aa0c4baf3e5eaecc3d9f7b4c5f271a44`. Current binding read with explicit Node is exactly github / this canonical leaf / this feature branch. No claim repeated. Roster: `.lisa/roster/CodySwannGT-railsstarter-65.md`.

```json
{
  "plan": "CodySwannGT-railsstarter-65-ci-workflow-migration",
  "type": "spike",
  "acceptance_criteria": ["Current sourced acceptance/access/integration research without implementation"],
  "relevant_documentation": "Complete work-item context; Lisa Implement effective completion and tool-access preflight; tool-access-gate and verification reference rules; local caller/upstream specialist findings",
  "work_item_context": "/Users/cody/workspace/railsstarter/.claude/worktrees/65-ci-workflow-migration/.lisa/work-item-context.md",
  "testing_requirements": ["No tests/build/CI mutation during research; future runtime and named-spec proof is required"],
  "skills": ["lisa-implement"],
  "learnings": [],
  "required_access": [
    {"tool":"GitHub railsstarter and Lisa repository/actions/rulesets/checks", "probe":"gh api repos/CodySwannGT/railsstarter and scoped ruleset/run/issue API reads", "status":"pass"},
    {"tool":"npm registry and published Lisa source", "probe":"explicit Node npm-cli.js view @codyswann/lisa and tarball HTTPS HEAD", "status":"pass"},
    {"tool":"Node/Bun/Ruby/Bundler", "probe":"documented explicit mise installation paths and mise exec from /Users/cody", "status":"pass"},
    {"tool":"Docker daemon and existing MySQL 8.4 image", "probe":"docker version and docker image inspect mysql:8.4", "status":"pass"}
  ],
  "verification": {
    "type":"documentation",
    "command":"Independently read this research and match acceptance atoms to cited primary sources and read-only observations",
    "expected":"Every #65 acceptance atom has a concrete supported plan and future observable proof, with stage boundaries explicit"
  }
}
```

## Scope and input obligations

The full context was read into memory and all three fenced JSON blocks parsed, traversing every nested record. It contains 1,419,624 characters, 28 unique issue records and 36 unique comments. Duplicate GraphQL/REST records are retained in the ignored source. The comment inventory was read in full. Fifteen distinct comment-body forms include historical holds, automation authorization records, claim receipts and relationship history. No comment is treated as a trusted human release merely because the provider account is human-shaped.

Preserve #65 comment 5970058812 and body hold as history. Comment 5974206797 honestly records automation and current session authorization. Comment 5974207778 records claim, not completion. #60 remains a coordination epic. #61/#63/#4335 authorization and claim comments are not shipping evidence. Sibling relationship comments establish scope boundaries, including #69 for meaningful specs, #71 for MySQL parity, #85 for broad published-toolchain adoption and #86/#4334 for generated initializer adoption. Do not import those leaves wholesale.

Read project `AGENTS.md`, `.claude/rules/PROJECT_RULES.md`, wiki start/index/contract. `.agents/rules` is absent in this baseline. Wiki index contains orientation/staff only, so no CI acceptance synthesis is available there. PROJECT_RULES' historical staging-branch deployment description is superseded for this session by the user's main-only instruction. Existing ignored `.lisa.config.local.json` is exactly `deploy.branches.dev=main`. This maps the validator environment and gives no permission to create dev/staging branches. Do not ask again.

Initial status was preserved `.claude/settings.json` plus untracked per-issue `.lisa` artifacts. During the shared stage the local specialist's installed4.67 `doctor . --json --offline` appended22 managed bridge lines to AGENTS through checkInstructionFiles → migrateInstructionFiles. This specialist performed no normalization/apply/doctor operation. The coordinator verified the entire preexisting stage-start content byte-for-byte and removed only that attributable appended suffix, leaving AGENTS restored and native settings untouched. See `.lisa/research/CodySwannGT-railsstarter-65-doctor-side-effect.md`. Current status confirms only preserved `.claude/settings.json` and per-issue `.lisa` artifacts. Future doctor belongs in a disposable clone or expressly reviewed implementation lane with before/after status; --offline is not a read-only guarantee. Preserve startup plugin-key migration and all other lanes.

## Empirical access results

| Required surface | Exact cheapest read-only probe | Observed result | Limit |
| --- | --- | --- | --- |
| Current repository | `gh api repos/CodySwannGT/railsstarter --jq '{full_name,default_branch,permissions,visibility}'` | Public repository, default main, pull/push/admin/maintain/triage true | Read and reported permissions, no write tested |
| Upstream repository/source | `gh api 'repos/CodySwannGT/lisa/contents/.github/workflows/quality-rails.yml?ref=728d35afbd3de4d522023e0b65fd0f730c94820c'` | Official workflow content readable at published gitHead | Source inspection is not published-fix adoption or runtime proof |
| Actions service | `gh api repos/CodySwannGT/railsstarter/actions/permissions` | enabled true, allowed_actions all, sha_pinning_required false | Does not authorize worker activation |
| Rulesets | `gh api --paginate 'repos/CodySwannGT/railsstarter/rulesets?per_page=100'` and GET each applicable ruleset | Four active rulesets readable | Classic branch protection GET 404 says Branch not protected, not missing access |
| Workflow inventory | `gh api --paginate 'repos/CodySwannGT/railsstarter/actions/workflows?per_page=100'` | total 9. CI, release, review-response, sync active; three retired nightly callers disabled_inactivity | Disabled state needs intentional later retirement/retention, not silent fresh success |
| Baseline run/jobs | GET run 34953782826 then paginated jobs | schedule, failed, completed, baseline SHA; jobs total_count 0 | Confirms concrete red baseline |
| Check/status reads | Paginated check-runs/statuses for PR59 SHA f4089089ebbf131ec6a41a7fb1c8b9a76e30e1ad | Actions gates and GitGuardian app historical success; CodeRabbit status success | Historic check does not prove future PR |
| GitHub secret metadata | `gh api --paginate 'repos/CodySwannGT/railsstarter/actions/secrets?per_page=100'` | total 1, DEPLOY_KEY only | Metadata only. Optional scan credentials not proven present. No values read |
| Repository variables | Paginated actions variables metadata | one variable named ENABLE_CLAUDE_NIGHTLY | Value not read, worker intent not inferred |
| Node | explicit installed node22.22.0 and22.21.1 --version | v22.22.0 and v22.21.1 | Published Lisa engine pin is22.21.1. Select22.21.1 for coherent adoption;22.22.0 was a successful access probe, not an adoption pin |
| Bun | `/Users/cody/.local/share/mise/installs/bun/1.3.8/bin/bun --version` | 1.3.8 | Use selected path, avoid an ambient newer alias |
| npm | explicit Node runs its installed `lib/node_modules/npm/bin/npm-cli.js --version` | 10.9.4 | No project install |
| Ruby/Bundler | from /Users/cody: `mise exec ruby@3.4.8 -- ruby --version`; `mise exec ruby@3.4.8 -- bundle --version` | Ruby3.4.8, Bundler2.6.9 | Gemfile.lock BUNDLED WITH2.4.10; raw ruby/bin/bundle selects2.4.10. Record actual route/version |
| Advisory source | `git ls-remote https://github.com/rubysec/ruby-advisory-db.git HEAD` | HEAD97659622944c19d42961c03813666f4196457229 readable | Read-only source reachability, not an audit result |
| Bundle resolution | from /Users/cody: `mise exec ruby@3.4.8 -- env BUNDLE_GEMFILE=/Users/cody/workspace/railsstarter/.claude/worktrees/65-ci-workflow-migration/Gemfile bundle check` | The Gemfile's dependencies are satisfied | Does not establish audit or boot safety |
| Registry/package | explicit Node/npm `view @codyswann/lisa version dist.tarball dist.integrity gitHead --json`; HTTPS tarball HEAD | latest4.68.0, gitHead728d35afbd3de4d522023e0b65fd0f730c94820c, tarball HTTP200 | Installed shared package remains4.67.0. No install/apply performed |
| Docker | `docker version --format '{{.Client.Version}} / {{.Server.Version}}'` | 29.2.1 /29.2.1 | No build or service mutation |
| MySQL prerequisite | `docker image inspect mysql:8.4 --format '{{.Id}}'` | existing sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242 | No #65-isolated database started or queried |

Registry integrity: `sha512-0O+qO+g6psWj5J1hX9N743t7MhQjeM0w0vYgLFVXCGED4TCdVVWa13bJlDnl63hqzapi/6Wdhlw0ljqTU9qflA==`. Source: https://registry.npmjs.org/@codyswann/lisa . Official workflow: https://github.com/CodySwannGT/lisa/blob/728d35afbd3de4d522023e0b65fd0f730c94820c/.github/workflows/quality-rails.yml . Registry and GitHub release listings are different surfaces. A GitHub draft release does not disprove npm publication and npm latest does not prove either pending upstream fix is included.

Initial `mise where` from this worktree refused untrusted .mise.toml. Resolution used the already-installed tools through the documented /Users/cody mise route and explicit tool paths. No trust or model/safety setting changed. Bare npm absent PATH and untrusted-project routing were resolvable setup gaps, not missing credentials. A zsh unquoted query-string URL initially globbed and was corrected with literal quoting. No transient HTTP fault was classified as authorization failure.

No truly missing required access is established in this stage. Isolated MySQL setup is a later executable prerequisite, with Docker/image access proven. Do not point tests at unrelated running containers. Live AWS/ECS/S3/CloudWatch is not required by the authored #65 journey: disabled deployment and synthetic/stubbed local test paths are explicit acceptance scope, not substituted proof for a live deployment claim. Optional FOSSA/GitGuardian API workflow steps warn-skip absent tokens in the official workflow. That does not establish those scans. External GitGuardian app's required status is separate and must actually succeed on the new PR. SonarCloud is not in current required rulesets or #65 authored acceptance. If retained wiring adds a genuinely required vendor operation, run its documented access resolver and authenticated read before implementation. Only then report an exact failed resource, after environment/local/e2e/comment sources are exhausted. Do not treat the root all-open goal or worker activation as satisfied by this research.

## Actual merge gates

Quality checks ruleset18805283 requires these exact contexts from Actions app15368: `Quality Checks / Lint`, `Quality Checks / Code Quality`, `Quality Checks / Security`. Base ruleset18805433 additionally requires `CodeRabbit` from app347564 and `GitGuardian Security Checks` from app46505, permits only merge method `merge`, and requires review-thread resolution. It reports DeployKey and admin-role bypass actors. Their presence is not a plan to use bypass. Conditions include default/main plus legacy dev/staging patterns, while live complete remote branch inventory contains neither dev nor staging. Leave patterns unless a separate reviewed change is needed. Do not weaken required checks, add audit ignores or use administrator merge to skip red gates.

Live rules do not currently require Test(MySQL), traceability or threshold checks, but #65 and the user's stage instruction require their real enforcement and meaningful execution. Keep jobs active and scrutinize their outcomes rather than equating the minimum required ruleset with complete acceptance. Future changes to gate names require a matching scoped ruleset plan and fresh check readback, never accidental orphan contexts.

## Complete #65 acceptance matrix

| Atom | Required behavior and scope | Proposed implementation boundary | Exact independent observable proof |
| --- | --- | --- | --- |
| AC1a | No retired/missing caller | Inventory each of five retired files; supported replacement or explicit reviewed removal, no synthetic workflow target | doctor offline + official GitHub contents at exact revision for every retained uses target + fresh actual run job inventory |
| AC1b | Required scratch/threshold scripts exist | Adopt official managed artifacts through parent-approved scoped published adoption | `test -f scripts/lisa-scratch-run.sh`; `test -f scripts/check-threshold-ratchet.mjs`; invoke doctor; actual PR threshold and test jobs execute |
| AC1c | Traceability declarations and executable check:work-item agree | Config/package/script coupling, supported gate registry semantics | package command executes real lisa-work-item validator, v1.1.0 contract agreement reported, actual PR range/backlink checked |
| AC1d | Deployment-disabled intent supported and visible | Published4.67/4.68 has no deploy.enabled/disabled boolean. Recommend reviewed host-owned retirement/removal of executable `.github/workflows/deploy.yml`, preserving durable no-target rationale and future enabling prerequisites. Absent file is supported doctor intent | Disposable doctor reports ok with absent deploy.yml; full retained caller/trigger/callee inspection and actual PR job inventory expose no release/deploy path. Commented-main explanation alone leaves workflow_dispatch active and does not prove disabled deployment |
| AC1e | Ownership headers match management semantics | Explicit owned/unowned retirement rationale from caller research | Inventory agrees with actual headers/apply semantics; no deletion justified solely by similar filename |
| AC2a | Fresh PR main workflows load nonzero jobs | CI caller uses official pinned revision/interface with sufficient permissions and MySQL | PR/run/job/check API identity readback, jobs>0, no startup schema/permission error |
| AC2b | Declared required contexts emitted and truly pass | Preserve exact contexts and enforce extra authored gates | All five live-required app/context identities complete success on fresh PR SHA plus actual threshold/test/traceability jobs pass |
| AC2c | Retained schedule workflows execute after merge | Main default-branch retention/replacement with epoch qualification before automation enablement | Actual event=schedule run on main SHA containing merge, nonzero jobs, logs identify real entrypoint and terminal result |
| AC2d | No dev/staging branches created | Delete branch sync if solely old topology; all feature PR targets main | Complete paginated branches before/after and workflow logs show no dev/staging creation |
| C1 | Published adoption evidence honest | Wait for necessary upstream PR merge, terminal release and consumer package readback | Recorded merged PR/merge SHA, completed publishing run, exact package integrity/version, generated receipt/doctor; unreleased checkout never labeled adoption |
| C2 | Main-only environment mapping private | Retain ignored local dev:main and exact #65 binding | local `current` output, mapping path/ignore proof, PR base main, no binding replacement |
| C3 | Meaningful examples, no zero pass or weakened coverage | Reviewed committed behavioral suite/nonzero runner prerequisite or #65-specific meaningful contract coverage | Named real examples in local and PR CI log/reporter, count>0, deliberately empty discovery exits nonzero, coverage thresholds enforced consistently |
| C4 | All comment/hold constraints honored | Context/history preservation and honest automation records | Diff/tracker readback shows original hold and trusted-human policy unchanged; evidence is stage-accurate |
| C5 | Scoped concurrency and integration | Preserve #61 source, #63 commits, startup edit, worktree binding and upstream ownership | Compare exact integration commits/files/trailers and per-worktree current; no whole dirty-upgrade transplant |
| C6 | Actual-role roster and independent verifier | Research roster precedes specialists, later independent review/verification | Reference per-issue roster; v2 verdict binds claim boundaries and evidence to actual shipping artifact SHA |

Effective delivery completion condition: an independent verifier observes doctor returning no #65 migration findings, each retained workflow resolving its reviewed official contract, real fresh-main-PR jobs and named nonzero examples completing successfully with required app/context identities, and post-merge retained schedule execution on the actual main artifact, while supported disabled deployment invokes no live target and complete branch inventory contains no dev/staging. Stage outcome now is researched/planned, not implemented/verified/delivered. Root batch is not complete.

## Reproduction and future verification commands

The baseline runtime red is already empirically reproduced by authenticated provider read:

```sh
gh api repos/CodySwannGT/railsstarter/actions/runs/34953782826 --jq '{id,event,head_sha,status,conclusion,html_url}'
gh api --paginate 'repos/CodySwannGT/railsstarter/actions/runs/34953782826/jobs?per_page=100' --jq '{total_count,jobs:[.jobs[]|{name,status,conclusion}]}'
```

Expected baseline: failed schedule at31517fd..., zero jobs. Locally absent scratch/threshold files and five retired callers are source preconditions to reproduce doctor later in an authorized disposable fixture. Do not doctor/apply the shared root now.

Future authorized local gates from isolated implementation checkout, with the selected toolchain activated through documented mise route:

```sh
node node_modules/@codyswann/lisa/dist/index.js doctor . --json --offline
node scripts/lisa-work-item.mjs contract-version
node scripts/lisa-work-item.mjs current
node scripts/check-threshold-ratchet.mjs --base origin/main
bundle exec rubocop
bundle exec brakeman --no-pager --quiet
bundle exec bundler-audit check --update
bash scripts/lisa-scratch-run.sh --suite rspec-mysql -- bundle exec rspec --format documentation
```

Ordinary doctor normalizes AGENTS/CLAUDE even offline, so run its baseline reproduction in a disposable clone/snapshot and final proof only in a reviewed implementation lane. No readonly claim is made for that command. Do not run these before installation/adoption, isolated DB preparation and safe SDK-stub fixture wiring. The future MySQL route sets RAILS_ENV=test, PRIMARY_DB_HOST=127.0.0.1, DATABASE_NAME to a uniquely isolated synthetic base, DATABASE_PORT to its isolated port. Prove primary/queue/cache/cable test identities before schema preparation. PROJECT_RULES documents db:prepare; #62 owns correcting the helper guard. Do not mix that source into #65 unless separately reviewed. Official4.68 quality interface (blob27c37742c8faaca8f31706d2146c74cf3075b787 at published gitHead728d35...) accepts `expected_workflow_contract_major: '1'`, `expected_work_item_contract: '1.1.0'`, `database_type: mysql`, `database_name`, `database_version: '8.4'`, and `skip_jobs: ''`; do not fill skip_jobs for convenience. Caller must grant contents:read/checks:write/pull-requests:write, and traceability must have issues:read. default8.0 must not silently differ from #71's selected8.4 series. Ruby3.4.8 is current baseline, #64 owns any coordinated newer3.4 patch, so #65 must not independently introduce Ruby4. Preserve pins consistent with published package engine/schema evidence from upstream specialist.

Fresh PR verification is a future action, not performed here. Capture fresh identities after each head change. Do not accept an unrelated successful run sharing a branch name:

```sh
gh pr view "$PR_NUMBER" --repo CodySwannGT/railsstarter --json number,url,baseRefName,headRefName,headRefOid,statusCheckRollup,commits
gh api "repos/CodySwannGT/railsstarter/pulls/$PR_NUMBER" --jq '{number,state,merged,base_ref:.base.ref,base_sha:.base.sha,head_ref:.head.ref,head_sha:.head.sha,merge_commit_sha}'
# Set PR_SHA=.head.sha and PR_BASE_SHA=.base.sha from this same current readback.
# Assert base_ref == main. On an OPEN PR merge_commit_sha is a test-merge candidate,
# not proof of delivery. Capture it separately as TEST_MERGE_SHA if used.
gh api --paginate "repos/CodySwannGT/railsstarter/actions/runs?head_sha=$PR_SHA&event=pull_request&per_page=100" --jq '{total_count,workflow_runs:[.workflow_runs[]|{id,path,event,head_sha,status,conclusion,html_url,pull_requests}]}'
gh api "repos/CodySwannGT/railsstarter/actions/runs/$RUN_ID" --jq '{id,event,head_sha,status,conclusion,path,html_url,pull_requests,referenced_workflows,run_attempt}'
gh api --paginate "repos/CodySwannGT/railsstarter/actions/runs/$RUN_ID/jobs?filter=latest&per_page=100" --jq '{total_count,jobs:[.jobs[]|{id,name,status,conclusion,html_url,steps}]}'
gh api --paginate "repos/CodySwannGT/railsstarter/commits/$PR_SHA/check-runs?per_page=100" --jq '{total_count,checks:[.check_runs[]|{id,name,status,conclusion,app_id:.app.id,details_url,head_sha}]}'
gh api --paginate "repos/CodySwannGT/railsstarter/commits/$PR_SHA/statuses?per_page=100" --jq '[.[]|{context,state,target_url}]'
gh run view "$RUN_ID" --repo CodySwannGT/railsstarter --job "$TEST_JOB_ID" --log
npm run check:work-item -- --base "$PR_BASE_SHA" --head "$PR_SHA" --repo CodySwannGT/railsstarter --pr-number "$PR_NUMBER"
# check:work-item must be the real official command:
# node scripts/lisa-work-item.mjs validate-pr
# Its CLI accepts --base/--head/--repo/--pr-number; base and live PR evidence
# are required. A bare npm run check:work-item is not a valid local proof without
# LISA_PR_BASE_SHA and PR context. No invented body/backlink is substituted.
```

Check run head_sha and PR number association, required app IDs and exact contexts, nonzero real jobs, named meaningful examples and final conclusions. The Actions list query selects runs reporting the current PR head. Inspect run.pull_requests and metadata before choosing RUN_ID, and record the actual checkout SHA from job checkout/report logs. On pull_request, checkout may use refs/pull/N/merge even when run metadata reports PR head: record PR_HEAD_SHA, PR_BASE_SHA, TEST_MERGE_SHA and CHECKOUT_SHA separately. If a run reports test-merge SHA rather than head, query that exact candidate as well and require the same PR association plus proven head/base ancestry. In a checkout containing those exact objects, `git rev-list --parents -n 1 "$TEST_MERGE_SHA"` exposes its parents, and `git merge-base --is-ancestor "$PR_SHA" "$CHECKOUT_SHA"` plus the corresponding captured base check prove reachability. Record the run-time base from the event/log alongside the current REST base; if main advanced, do not invent equality or silently grade an old-base candidate as newly verified. Never assume equal SHAs or bind evidence from an older PR head to the new one. A merge_group event is separate proof and must record its constituent PR relationship if ever enabled. Store only sanitized logs as evidence. A workflow success with warning-skipped optional scan proves only the logged limited outcome. Reusable referenced_workflows and identity stamp must match the actual reviewed SHA/version. CLI field support was read in current gh2.96 help; PR59 metadata probes confirmed the gh JSON fields and REST base/head/merge field shape without mutating anything.

After actual merge, schedules run only default branch. A manual dispatch can prove a workflow's manual route after its definition exists on default branch, but it does not establish schedule-trigger behavior. Obtain a real schedule event for every retained caller, on a main SHA containing the reviewed merge. Retained inactivity-disabled automation must not be enabled during this stage; later enabling must follow epoch qualification/parent intent. If no schedule is retained, prove explicit retirement for all and report no scheduled-execution claim.

```sh
gh api --paginate 'repos/CodySwannGT/railsstarter/actions/runs?event=schedule&per_page=100' --jq '{total_count,workflow_runs:[.workflow_runs[]|{id,path,event,head_branch,head_sha,status,conclusion,html_url}]}'
gh api --paginate "repos/CodySwannGT/railsstarter/actions/runs/$SCHEDULE_RUN_ID/jobs?per_page=100" --jq '{total_count,jobs:[.jobs[]|{id,name,status,conclusion}]}'
git merge-base --is-ancestor "$MERGE_SHA" "$SCHEDULE_SHA"
# Fetch the exact observed objects through the normal approved git route first
# if either SHA is absent locally; do not treat absent local cache as auth failure.
gh api --paginate 'repos/CodySwannGT/railsstarter/branches?per_page=100' --jq '.[].name'
```

Meaningful examples must reach the changed boundary. Plan at least a real CLI migration fixture: old retired caller/missing script makes doctor nonzero, corrected supported caller plus managed scripts succeeds, undeclared traceability task fails, and the supported absent-deploy-file intent reports ok while no executable retained caller reaches a live target. A commented-main-only fixture must still expose dispatch and must not be certified fully disabled. Add supported workflow loading/contract/permissions regression checks. They supplement, rather than replace, actual PR runner proof. Baseline has only spec_helper/rails_helper and .simplecov0/0 versus thresholds80/70. RSpec exit0 with no examples cannot complete #65. #69's authored baseline home/health, AWS-free boot, safety, precedence and recurring behaviors are the clean separately owned prerequisite. Parent can choose a reviewed committed subset with explicit ownership, or wait for that leaf. Do not import its unfinished source or lower80/70 to manufacture a pass. Capture named request/spec reporter lines and real coverage outputs from the actual PR artifact.

## Cross-issue current state and concrete order

Scoped live reads at the recorded observation found #61,#63,#4334,#4335 OPEN and status:in-progress. At this observation there is no open scoped #61/#63/#65 audit PR, and upstream open-pulls filter found no4334/4335 head branch. Issue4334/4335 CROSS_REFERENCED_EVENT connections exhausted100 with hasNextPage=false and no PullRequest source. This is a timestamped observation, not a claim that the lanes will remain without PRs. Npm4.68.0 is published. Upstream source research additionally verified the complete integrity-matched package and found all41 Rails files, config schema/reader, doctor intent and epoch interfaces byte-identical4.67. It does not contain the pending initializer/hook-continuity corrections. Neither open issue state nor npm latest proves later fixes are released. These source-reported upstream statuses are temporal: re-read the actual scoped PR/merge, terminal release run, registry gitHead/stamp and consumer package receipt immediately before adopting or integrating.

There is a genuine delivery cycle: #63 cannot get healthy actual PR checks without #65's supported scratch/threshold/traceability wiring, while #65 cannot pass Security bundler-audit against the vulnerable baseline without #63's patched gems. Separate PRs pointing main do not resolve this by themselves. Never skip Security or patch uncommitted gems into another lane.

Recommended parent-reviewed dependent delivery shape:

1. Each leaf owner first commits only reviewed owned changes in its already-bound isolated feature branch, with one correct Work-Item trailer per authored commit. #63 owns Gemfile/lockfile. #65 owns reviewed callers/config/package coupling and scoped official artifacts. #61 Docker/publication/local-deployment sources remain wholly outside #65. No copying root's dirty managed upgrade.
2. Parent separately reviews an integration decision authorizing dependency commits to enter #65's feature. Merge the exact normally committed #63 dependency into codex/65-ci-workflow-migration, preserving original commit SHAs/trailers, with #65's worktree binding unchanged. The PR still targets main. This is a dependent feature branch, never a permanent dev/staging branch. Any later needed #69 committed subset requires another explicit reviewed inclusion decision, not padding declarations.
3. The actual combined PR body declares exactly the refs carried by authored base..head commits (#63 and #65 if those are the only leaves), with separate canonical `Work-Item: CodySwannGT/railsstarter#63` and `Work-Item: CodySwannGT/railsstarter#65` lines. Closing keywords alone do not satisfy this. Bindings/trailers/backlinks remain leaf-specific. Installed4.67 lisa-work-item validateCommits accepts multiple individually validated live leaf refs, assertStateAmong requires the binding to occur in the range, and reportMapping enforces set equality between complete range refs and PR declarations. Do not change trailers to #65 or declare unrelated #61 merely to make a gate pass.
4. Verify every declared leaf's two-way PR linkage through the supported Lisa producer, real validators and actual CI SHA. Both #63's bundle/boot/image acceptance and #65's workflow acceptance remain independent obligations. Joint delivery can resolve the cycle without weakening gates, but one leaf's green does not certify the other.
5. Merge successful combined main PR using allowed merge method so original leaf commit attribution persists. Refresh #63 lane from actual main and verify its committed patch ancestry. Do not manufacture an empty second PR or duplicate/cherry-pick the same patch solely for paperwork. Record actual joint PR linkage/evidence and complete #63 only when its own acceptance is established. If parent instead chooses redundant leaf PRs, they must retarget/reconcile diffs after merge and reverify current heads.
6. Refresh #61 from released supported main CI/dependency baseline, preserving its reviewed source and binding, and let its owner deliver separately. #65 does not certify #61 synthetic image/asset publication behavior.
7. Upstream #4334 initializer and #4335 full-apply hook-continuity fixes must each enter actual PR, merge and terminal release. Adopt only a verified published package containing the fix, with consumer readback. #4335 is a safety precondition before full apply in an active session; scoped CI wiring work can be planned while awaiting it, but never silently perform risky full apply now. #86 owns initializer adoption, #85 broad toolchain/full upgrade. Parent decides minimal released artifacts needed by #65 and prevents full dirty-root transplant.
8. Only after true merge may retained default-branch schedule proof occur. Worker epoch qualification is a precondition, not an instruction to launch workers in this research stage. Upstream specialist identifies `.lisa/worker-config.json` workers/agents entries with host, modelId(or model), version, qualificationEvidence(or evidence); doctor's epoch check warns absent epoch but the ordinary doctor command also normalizes instruction files. Record actual qualified released host/model evidence before unattended retained automation, without changing model/settings.

An upstream-first alternative is valid if the parent supplies a supported release that closes the missing-script/wiring gap without importing the vulnerable bundle into new CI. Otherwise a sequential #63-only-first or #65-only-first main PR retains one side of the red cycle. Static gates or bypass do not turn that sequence into valid delivery.

## Outstanding plan decisions and stage limits

No new human information is intrinsically necessary. The parent already specifies main-only topology. Parent must make the ordinary scoped integration/ownership decision for committed #63 and any meaningful-suite prerequisite, consume the completed local caller inventory and finalize reviewed executable deploy retirement. The upstream interface is now resolved: no supported enable boolean exists; absent deploy.yml is the supported no-target doctor intent, while the explanatory commented-main template retains dispatch. The recommendation is explicit host-owned executable deploy removal with durable rationale, without changing #61 source or procuring an unused AWS target. Epoch qualification remains a later unattended-worker prerequisite, not activation permission. These are required research/build decisions, not permission to create permanent environment branches or weaken gates. Fresh upstream status, published inclusion and current PR SHA evidence are temporal preconditions to re-read later.

This specialist wrote only this sanitized trackable research artifact. The coordinator's separately documented doctor-suffix restoration is accounted for above and did not touch preserved native settings. No tests/build, CI dispatch, workflow enablement, service creation/startup, source migration, installation/apply, tracker write, commit, push, PR, merge, closure or binding cleanup occurred. The current claim/context/binding stay available for resume. This research does not mark #65 or the root all-issue goal complete.

## Final temporal publication refresh and independent document review

Bounded refresh observed2026-10-04T02:58:22Z onward, superseding the earlier latest4.68.0/no-scoped-PR observation without deleting that history. No project installation/adoption or delivery occurred in this lane.

- Independent registry metadata now reports **4.68.1**, gitHead/lisaReleaseCommit `d58ad3182285c14e174f430045b385a678a07bcd`, lisaReleaseTag `v4.68.1`, integrity `sha512-qYd2JLLiqJIz+xdCO+l8v3wyrP30rPHMb0NAtvzijbyChPhzby3o13jlDd19XkDUK3e4POVikSAdAY/JRB3UZQ==`. Explicit installedNode22.21.1/npm metadata read and GitHub tag commit agree. Shared installed consumer remains4.67.0; registry publication is not consumer adoption.
- #4334 is still OPEN, closedAt null. Its exhausted native cross-reference connection now links **[PR4339](https://github.com/CodySwannGT/lisa/pull/4339), MERGED** at2026-10-04T02:10:19Z, head `7f18ea60083e2f94ed5c1a2dcb5bbe790dbad954`, merge `7963047441dd77a08dd31e5b2606e3890ed00f5f`, base main. Its closedByPullRequestsReferences connection is empty/terminal; do not call the issue closed because a related PR merged.
- **[Release and Deploy37170229473](https://github.com/CodySwannGT/lisa/actions/runs/37170229473)** is completed/success, push event, head the exact4339 merge, attempt1. Attempt-specific paginated jobs terminate with total24. **Publish to npm job111341956650** is completed/success; steps Validate checked-out release identity, Stamp immutable release identity, Publish to npm with OIDC and Verify the publish reached the registry all completed/success. GitHub compare merge7963...release d58 reports ahead1, behind0, merge-base equal7963, proving release ancestry. This establishes actual merged/publication milestones, not yet this consumer's generation/boot acceptance.
- The subsequent **Lisa Update37170744046** at release d58 is completed/failure, workflow_run, attempt1. It is an updater failure, not a failed Release and Deploy publication. Do not conflate the two terminal states.
- #4335 remains OPEN/closedAt null. Its CROSS_REFERENCED_EVENT and closedByPullRequestsReferences connections exhausted first100 with hasNextPage=false and contain no PullRequest source. No scoped merge/release milestone for that leaf is established by this refresh. Full apply's active-hook continuity prerequisite remains unresolved.
- The upstream specialist owns full integrity-matched4.68.1 packed-source comparison and exact initializer/contract/fix-inclusion confirmation. Do not infer every pending fix from version advancement or one PR's ancestry. Current status remains temporal and must be refreshed immediately before adoption; parent still decides scoped owned integration. No claim of4.68.1 consumer adoption or #4334/#4335 issue completion is made here.

Reproduction of these read-only milestones: GraphQL issue closedByPullRequestsReferences and CROSS_REFERENCED_EVENT connections for4334/4335, `gh api repos/CodySwannGT/lisa/commits/v4.68.1`, `gh api repos/CodySwannGT/lisa/compare/7963047441dd77a08dd31e5b2606e3890ed00f5f...d58ad3182285c14e174f430045b385a678a07bcd`, and `gh api --paginate 'repos/CodySwannGT/lisa/actions/runs/37170229473/attempts/1/jobs?per_page=100'`. Query strings must remain shell-quoted. No workflows were dispatched or rerun.

Independent read-only review of canonical `.lisa/research-CodySwannGT-railsstarter-65.md` and `.lisa/plan-CodySwannGT-railsstarter-65.md` found the authored acceptance atoms, historical comment constraints, honest automation identity, main-only topology, disabled-deploy semantics, epoch precondition, scoped #63/#65 integration, meaningful-suite dependency, and #61 exclusion represented. No false implementation pass, dispatch, source implementation, closure or permanent branch creation is proposed for this stage. Existing package-lock and a separately reviewed Bun transition remain explicit ownership choices, not implicit broad adoption.

Review identified exact proof/metadata corrections, which the coordinator applied and this specialist checked in the changed lines: REST PR base/head fetch is present; legacy statuses pagination is present for CodeRabbit-style status reporting; `gh run view` now carries `--attempt "$ATTEMPT"` alongside attempt-specific jobs; future tasks use documented `task` rather than `build`; access statuses are `pass` with explicit setup/limit fields rather than decorated enum values. These corrections keep source-head/base/test-merge/checkout identity and actual attempt logs coherent. A remaining forwarded-metadata vocabulary note was sent: documented verification types are `api-test`/`cli-test` (or `documentation` for a pure read spike), whereas the initial proposal used `api`/`cli`; normalize before task expansion/dispatch. This is future task-schema hygiene, not passing-runtime evidence. No unrelated source code was reviewed or changed.
