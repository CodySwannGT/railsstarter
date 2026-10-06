# Local caller research: CodySwannGT/railsstarter#65

Research only, observed 2026-10-03. Author: automation, bounded explorer teammate `/root/local_caller_research`. Exclusive ownership: this artifact. No intentional source edits, installation/apply, test/build, claim, tracker mutation, commit, push, PR, merge or worker activation occurred. The once-run Lisa doctor unexpectedly mutated AGENTS.md through its instruction-file repair check. This side effect is disclosed below. The coordinator subsequently proved and removed only the exact attributable appended suffix, restoring stage-start bytes, as documented in [doctor side-effect/restoration record](CodySwannGT-railsstarter-65-doctor-side-effect.md).

## Metadata

```json
{
  "plan": "CodySwannGT-railsstarter-65-ci-workflow-migration",
  "type": "spike",
  "acceptance_criteria": ["Provide current sourced local caller, script, ownership and history research without implementation"],
  "relevant_documentation": "AGENTS.md; .claude/rules/PROJECT_RULES.md; wiki/start-here.md; wiki/schema/llm-wiki-contract.md; wiki/index.md; installed Lisa 4.67.0 lisa-implement and lisa-wiki-query skills; listed installed templates and compiled ownership/pinning modules",
  "work_item_context": "/Users/cody/workspace/railsstarter/.claude/worktrees/65-ci-workflow-migration/.lisa/work-item-context.md",
  "testing_requirements": ["Research runs no suite/build/CI or install/apply; future verification must prove nonzero meaningful examples and actual PR-head workflow execution"],
  "skills": ["lisa-implement", "lisa-wiki-query"],
  "learnings": [],
  "required_access": [
    {"tool":"local git/source", "probe":"pwd; git branch --show-current; git rev-parse HEAD origin/main; git status --short", "status":"pass"},
    {"tool":"documented Node/mise resolver", "probe":"/Users/cody/.local/share/mise/installs/node/22.22.0/bin/node -p installed-package-metadata", "status":"pass"},
    {"tool":"local wiki resolver", "probe":"/Users/cody/.local/share/mise/installs/node/22.22.0/bin/node node_modules/@codyswann/lisa/plugins/lisa-wiki/scripts/ensure-wiki.mjs --json", "status":"pass"},
    {"tool":"GitHub repository read", "probe":"gh api repos/CodySwannGT/railsstarter --jq '{full_name,default_branch,permissions}'", "status":"pass"}
  ],
  "verification": {"type":"documentation", "command":"Match local findings below to observed baseline files, immutable path-history commits and installed Lisa source, then reconcile official current release/workflow evidence from the upstream specialist", "expected":"Every scoped claim has observable evidence and retained limitations; implementation remains pending"}
}
```

## Isolation and full-context review

Actual cwd: `/Users/cody/workspace/railsstarter/.claude/worktrees/65-ci-workflow-migration`. Branch: `codex/65-ci-workflow-migration`. HEAD and local origin/main both `31517fd9aa0c4baf3e5eaecc3d9f7b4c5f271a44`. Initial status: existing `.claude/settings.json` modification and research `.lisa/` files. A later read observed an additional AGENTS.md modification. Attribution found the once-run doctor instruction-file repair, not another participant. Coordinator subsequently restored only those attributable additions after exact byte comparison. No remote main fetch was performed by this specialist, so this is local ref readback, with fresh provider read owned elsewhere.

Read task prompt and per-issue roster before research. Complete context was read as 1,419,624 characters, all three JSON blocks parsed, and issue bodies/comments recursively inspected with duplicate records removed for display. Primary #65 requires: retire or replace five missing callers with rationale, keep main integration, align traceability command/declarations, state disabled deployment honestly, reconcile ownership headers, qualify worker epoch before activation, inspect actual rulesets/contexts, prove doctor/ref/script success and fresh PR/retained schedule runtime evidence. The issue and parent historical hold remain preserved. Current session scope supersedes hold for authorized leaf work, never establishes trusted-human identity. Related comments and leaves preserve separate ownership and do not authorize combining all audit fixes here.

`.agents/rules` is absent at this baseline. `.claude/rules/PROJECT_RULES.md` is the only checked-in host rule file and was read in full. It requires Ruby 3.4.8 via mise, MySQL TCP `127.0.0.1` for host commands, four databases, real pre-push checks and no Reek suppression without explicit human authorization. Its staging deployment prose is stale relative to the current user's main-only operator instruction and belongs in coordinated host documentation cleanup, not a reason to create staging/dev.

Wiki-first read: installed `lisa-wiki-query` resolver succeeds now with local root `<worktree>/wiki`, `mirrored=false`, `fetched=false`, `stale=false`, `offline=false`. The historical audit's missing-helper observation is obsolete for installed Lisa 4.67.0. `wiki/index.md` contains orientation and staff only, no CI synthesis or source decision. Code/history fallback is necessary. No wiki files were written.

Full context and local mapping are ignored. `git check-ignore -v .lisa/work-item-context.md` reports common git info/exclude line 8. This research artifact is deliberately trackable. `.lisa.config.local.json` is `{ "deploy": { "branches": { "dev": "main" } } }`: private validator environment mapping only. Main remains the only permanent integration branch, feature/PR target main.

## Caller inventory and proposed disposition

All baseline caller sources can be cited immutably under `https://github.com/CodySwannGT/railsstarter/blob/31517fd9aa0c4baf3e5eaecc3d9f7b4c5f271a44/<path>`.

| Exact baseline path | Current purpose/interface | Scoped migration or retirement plan |
| --- | --- | --- |
| `.github/workflows/ci.yml` | PR/manual `Quality Checks` calling `quality-rails.yml@main`; MySQL type and `railsdb`; token contents:read, checks:write, PR:write; optional GitGuardian/FOSSA secrets | Keep quality CI. Explicitly reviewed caller migration to supported immutable release commit, supported contract-major input, MySQL 8.4 input coordinated with #71, issues:read for GitHub traceability, and package/script/declaration alignment. Preserve checks, do not invent skip exemptions. |
| `.github/workflows/claude-code-review-response.yml` | `pull_request_review submitted`, calls missing `reusable-claude-code-review-response.yml@main`; supplies review/PR identities, package_manager=none and Claude OAuth token | Retired host-customizable seed. Replace only if a supported current official review lane covers required behavior, otherwise explicitly retire obsolete Claude review automation with rationale and retain independent PR review gates. A mutable pin to an absent callee is not a repair. |
| `.github/workflows/claude-nightly-code-complexity.yml` | Weekday cron 05:00 UTC/manual, calls missing `reusable-claude-nightly-code-complexity-rails.yml@main` | Replace only with supported documented continuous/quality improvement route and immutable revision, preserving threshold-ratchet enforcement and qualifying worker epoch first. If intentionally retired, state that complexity remains enforced by quality checks and that autonomous reduction cadence ends. No worker activation implied. |
| `.github/workflows/claude-nightly-test-coverage.yml` | Weekday 04:00 UTC/manual, coverage_increment numeric default=5, calls missing `reusable-claude-nightly-test-coverage-rails.yml@main` | Supported replacement or explicit retirement rationale required. Retain real coverage thresholds and useful behavioral examples, no empty suite or coverage exemptions. Do not carry retired `coverage_increment` into a schema that omits it. |
| `.github/workflows/claude-nightly-test-improvement.yml` | Weekday 03:00 UTC/manual, mode nightly/general, calls missing `reusable-claude-nightly-test-improvement-rails.yml@main` | Supported replacement or explicit retirement rationale required. Do not invent mode compatibility. Current scheduled workflow evidence requires actual branch-aware safe runtime proof and later default-main schedule proof, not YAML inspection alone. |
| `.github/workflows/claude-sync-down-branches.yml` | Merged PR to main/staging triggers missing `reusable-claude-sync-down-branches.yml@main`, chain main→staging→dev | Retire with explicit rationale. Entire purpose is permanent environment-branch back-sync, directly inconsistent with main-only policy. No replacement branch-chain workflow. |
| `.github/workflows/deploy.yml` | Create-only AWS release/ECR/ECS orchestrator, push staging, manual dispatch, main commented out; `release-rails.yml@main` | State supported disabled-deployment intent through schema owned by upstream specialist. Do not merely uncomment main. Pin retained reusable/actions. Coordinate any caller/deploy change with #61 exact-image asset publication owner and #74 release identity/cancellation owner. No live AWS target is required for disabled behavior. |
| `.github/workflows/validate-pull-request.yml` | Host source from initial template; PR events; standalone RuboCop with `--fail-level F` and conditional SonarCloud based on secret presence | Inventory as overlapping legacy PR route. Review whether retained gates remain independent or are replaced by canonical quality CI after exact live required-context inspection. Do not remove an enforced context first. Pin retained checkout, Ruby setup and Sonar actions. Do not claim the optional Sonar skip proves analysis. |

No current supported replacement callee/schema decision is asserted here: current registry/upstream specialist owns that evidence. Template absence is not permission to disable a required gate, and retired automation removal must explain the lost capability rather than silently deleting it.

## Managed/host ownership and immutable history

Installed package `rails/deletions.json` names exactly the five retired caller paths with `basis: needs-review`. The installed `dist/core/workflow-deletion-ownership.js` documents why path-only deletion is refused: host-customizable seeds may contain host work, removal silently removes a check, and canonical header identity governs deletion. `dist/core/ownership-header.js` is the executable classifier.

Empirical Node import/classification of every current workflow: `ci.yml` is `lisa-managed`; all five legacy callers, `deploy.yml`, and `validate-pull-request.yml` are `unattributable`. This distinguishes machine classification from historical provenance: the five callers say “created by Lisa on first setup, customize, Lisa will not overwrite”, but that old wording does not match the newer canonical “Seeded by Lisa…this file is YOURS”. An automation claiming these bytes are proven Lisa-managed would be false. Explicit reviewed migration can correct their headers prospectively; do not forge them solely to allow automatic deletion.

Installed 4.67.0 `rails/create-only/.github/workflows/ci.yml` is host-owned seed now, with canonical ownership header, label/unlabel PR triggers, `expected_workflow_contract_major: '1'`, and issues:read. It still carries `@main` in the template because installed `dist/migrations/ensure-pinned-reusable-workflow-refs.js` resolves the installed release identity before writes, then pins all vouched callees. This migration's `vouchedCallees` only trusts callees referenced by shipped templates. Unsupported/retired callees cannot be repaired by blindly attaching the installed commit. The package does not ship its own reusable workflow directory, so verify GitHub contents at the resolved release SHA separately.

Managed scripts are `rails/copy-overwrite/scripts/...` and `all/copy-overwrite/scripts/...`, with durable changes upstream. Consumer `.simplecov`, thresholds and behavioral specs are host artifacts or create-only seeds. Never hand-edit overwritten scripts to accommodate an audit failure. No root dirty managed upgrade or #61 source was inspected/copied.

History citations:

- `87b994c58d22afd18f55d17c0e52d4eb703f046a` ([commit](https://github.com/CodySwannGT/railsstarter/commit/87b994c58d22afd18f55d17c0e52d4eb703f046a)): adds MySQL caller type and railsdb, preserves actual DB choice. Its authored comment about mutation skipping is dated historical reasoning, not authority to waive a current gate.
- `45709fea07dd97fe5d771c6a523b48274d1a8d31` ([commit](https://github.com/CodySwannGT/railsstarter/commit/45709fea07dd97fe5d771c6a523b48274d1a8d31)): grants checks/PR writes after observed GitHub startup_failure.
- `494b5a301033ea94181afd72e409a2b935082ad0`: last baseline package Lisa bump to 2.217.1.
- `e44f5ea80c108b367d447b8f6889936576b76373`: last review-response path change, Lisa update #20.
- `a266b6f0bc8f32251f02cd53ef3e7c9bdb80948c` and `550dffbfbcf21dec0240adfe46e9515d5b61022e`: relevant retired nightly/sync caller history.
- `83958786907049a0b76e3a3cbdc35aa04da9ec8c`: initial template includes standalone validate-pull-request route.

## Script, package and toolchain prerequisites

Baseline `package.json` declares only postinstall and `@codyswann/lisa: ^2.217.1`. Shared node_modules actually resolves Lisa 4.67.0 through the existing symlink `/Users/cody/workspace/railsstarter/node_modules`. Installing a package somewhere else is not shipping adoption in this lane. Baseline `.mise.toml` and `.ruby-version` both 3.4.8. There is no baseline Node/Bun pin. Installed Lisa package engines: Node 22.21.1, Bun 1.3.8, npm/yarn/pnpm “please-use-bun”. Actual explicit Node resolver available is 22.22.0, so coherent pin selection requires supported schema/release research rather than copying current PATH.

The native shell has no `node` on PATH. This is a resolvable runtime activation/setup prerequisite, not missing credentials. Explicit mise installation bin works. No toolchain was installed or changed.

Verified baseline absence:

- `scripts/lisa-scratch-run.sh`: required POSIX/Ruby scratch supervisor for Rails test routes. Installed managed template guarantees authority before allocation, scoped cleanup, payload status preservation and failure on leaked unregistered scratch. Do not bypass it.
- `scripts/check-threshold-ratchet.mjs`: CI `--base`, pre-commit `--staged`, hook `--hook`; prevents weakening thresholds and self-granted exemptions.
- `scripts/threshold-ratchet-families.mjs` and `scripts/threshold-ratchet-compare.mjs`: relative imports required by comparator. Shipping only entrypoint is incomplete.
- `check:work-item` package script: supported command is `node scripts/lisa-work-item.mjs validate-pr`; companion push command is `node scripts/lisa-work-item.mjs validate-push`. Installed TypeScript package-lisa force scripts show these, while Rails project has no generated package-lisa manifest.

`./scripts/lisa-work-item.mjs` currently exists only as resolver helper symlink into installed `all/copy-overwrite`; it imports `./lib/invoked-as-script.mjs` through the helper layout. It is not a tracked future CI artifact. Full official apply delivers managed entrypoint/dependency closure plus hooks/gates, and the final diff must be scoped/reviewed separately. Doctor reports many other missing universal guards, so adding just the two initially named scripts is insufficient for coherent installed artifacts.

## Empirical probes, doctor side effect and baseline diagnosis

- GitHub `gh api repos/CodySwannGT/railsstarter` succeeded, default branch main, authenticated pull/push/admin/maintain/triage permissions true. No credentials printed, changed or persisted.
- Wiki resolver command above succeeded and returned a current local root. This corrects the dated missing-helper assessment.
- Node installed-package metadata read succeeded, actual Lisa 4.67.0 engines reported above.
- Exact baseline `node node_modules/@codyswann/lisa/dist/index.js doctor . --json --offline` executed once using explicit Node and child PATH including its bin. Actual doctor exit **1**. Diagnostic metadata: absent `.lisa/apply-receipt.json`; no resolved Lisa enforcement guard; traceability undeclared due missing check:work-item; missing enforcement artifacts; unstated Rails production-deploy intent; all seven Lisa callers mutable @main (fail); two-channel drift for scratch and threshold entrypoints. Offline doctor says live rulesets/branch protection are unknown, so template agreement cannot establish merge enforcement. This was not a fresh CI pass. No full apply performed. Although invoked as a diagnostic, doctor is not wholly read-only: `dist/cli/doctor.js:203-225` documents `checkInstructionFiles` as mutating, calls `migrateInstructionFiles`, and executes it at line 333. That helper appended 22 lines to AGENTS.md: canonical `LISA_HOST_RULES_START/END` block requesting host rules and `LISA_PROJECT_LEARNINGS_START/END` Antigravity bounded-projection startup bridge with `.lisa/PROJECT_LEARNINGS.md` and missing-access prose. AGENTS.md mtime was `2026-10-03T21:47:16-0400`. Initial git status proved it was unchanged before the probe. This is an actual source mutation by the diagnostic, not an implementation change, and coordinator was notified. No restoration or overwrite was attempted by this specialist. Coordinator subsequently proved AGENTS.md was stage-start HEAD bytes plus only those exact 22 managed lines, removed just that suffix, and verified exact stage-start restoration. The native startup `.claude/settings.json` migration was preserved. See [doctor side-effect/restoration record](CodySwannGT-railsstarter-65-doctor-side-effect.md). `ensure-wiki.mjs` local mode ends at emit/process.exit and has no AGENTS writer, so it did not cause this change. Future strict read-only doctor probes must use a disposable complete copy or explicitly isolate the instruction repair, with evidence about the artifact inspected.

No required external access failure discovered in this bounded local scope. Registry/current upstream interfaces, database/Docker readiness, optional provider auth and actual rulesets/CI contexts are owned by other specialists. Optional secrets referenced in baseline workflows do not automatically create a need for a live deployment or nonconfigured integration.

## Actual examples and verification plan

`git ls-files spec` lists only `spec/rails_helper.rb` and `spec/spec_helper.rb`: no *_spec.rb examples exist. No test/ directory. `.simplecov` minimum lines/branches are 0/0 while `simplecov.thresholds.json` says 80/70. Existing `lefthook.yml` invokes raw `bundle exec rspec`, Brakeman, Reek, Flog, Flay and mutation. This is a documented zero-example/coverage disagreement, not a pass. #69 owns baseline suite/zero-example guard; #65 must receive meaningful reviewed examples before calling its required test route proof green. Existing routes provide real candidates: `GET /` → home#index and `GET /up` → Rails health, with `ApplicationController` modern-browser restriction and FlashHeaders. #61 verification artifacts can be integrated only by separate parent reviewed decision, not by copying dirty root source.

Exact future local commands after parent-authorized scoped build/adoption (not run here):

```sh
# Activate documented runtimes first, then identify the exact installed release.
node node_modules/@codyswann/lisa/dist/index.js doctor . --json --offline
node scripts/lisa-work-item.mjs contract-version
node scripts/lisa-work-item.mjs current
node scripts/check-threshold-ratchet.mjs --base origin/main
sh scripts/lisa-scratch-run.sh --suite rspec -- bundle exec rspec
PRIMARY_DB_HOST=127.0.0.1 RAILS_ENV=test bin/rails db:prepare
bundle exec rubocop
bundle exec brakeman --no-pager --quiet
```

MySQL preparation must use unique disposable test names, not a shared service reset. #62 safety improvements and host helper environment forcing must be respected. Run supported nonzero-example guard through the official test route and negative empty-directory fixture. Run real `/` and `/up` request specs with SDK stubs where relevant, not a no-op check. Match local/CI declared coverage without convenient exemptions.

Command validation: installed `all/copy-overwrite/scripts/lisa-work-item.mjs:6360-6362` implements `current` as JSON readback through `readState(false)`, and its CLI usage at line 6409 includes `current`. `show` is unsupported and has been corrected above. No claim/binding command was rerun.

Exact future provider evidence reads:

```sh
gh api repos/CodySwannGT/railsstarter/rulesets --paginate
gh api repos/CodySwannGT/railsstarter/branches/main/protection
gh pr checks <PR-number> --repo CodySwannGT/railsstarter --json name,state,link
gh run view <run-id> --repo CodySwannGT/railsstarter --json headSha,headBranch,event,status,conclusion,jobs
gh api repos/CodySwannGT/railsstarter/actions/runs/<run-id>/jobs --paginate
```

Before any later mutation, verify #65 binding exact readback and PR base main. Fresh PR proof must match feature head SHA and report real jobs/steps plus exact required contexts. Installed `lisa-verify-workflow-change` skill warns that schedules, issue comments and PR reviews execute default-branch definitions: those events cannot prove a changed branch caller. Use an existing safe dispatch sibling reaching identical behavior on the feature SHA only when authorized, observe target step and stop before agent/push/issue/PR/deploy side effects, then assert no side effects. If no supported safe sibling exists, record UNVERIFIABLE_PRE_MERGE and defer actual schedule proof until the approved main artifact, without presenting static validation as runtime success. This research stage dispatched nothing.

## Integration and unresolved decisions

1. Parent selects coherent released Lisa identity with upstream #4334/#4335 shipping proof. Do not treat unreleased patch or root install as published adoption. #85/#86 adoption scope remains distinct.
2. Preserve normally committed #63 Gemfile/lockfile leaf commits. #63 patch is needed for bundle audit gates. No ad-hoc ignores to bootstrap CI.
3. #65 owns reviewed supported CI caller wiring, script/declaration alignment and explicit retired-caller rationale. Full apply staging/diff ownership must be decided by parent separately from dirty root upgrade. #61 owns its image/publication/verification source. Conflicting deploy edits need reviewed minimal integration, never entire root cherry-pick.
4. Main-only integration: each feature branch and PR into main, ordered prerequisites or parent-reviewed integration branch if necessary, never permanent dev/staging. Keep separate worktree bindings and Work-Item trailers. Parent determines shared reviewed adoption commit ownership before research graduates to implementation.
5. Required green meaningful test route needs #69 examples or explicitly reviewed bounded real regression fixtures. Empty baseline suite cannot satisfy acceptance. Supported zero-example guard schema/route remains upstream research responsibility.
6. Runtime replacement choice for three nightly/review automation requires the supported official interface evidence. Disabled-deployment schema research is now settled: [upstream final research](CodySwannGT-railsstarter-65-upstream.md#disabled-deployment-actual-supported-semantics) confirms no executable `deploy.enabled` or equivalent boolean. The plan is explicit host-owned retirement/removal of the active deploy caller or an equally explicit non-executable deployment surface, with rationale and enabling prerequisites. A comment or invented configuration flag cannot disable workflow_dispatch. Coordinate retirement with #61 scoped ownership, and retain its separately reviewed construction/asset-publication source. These are implementation-planning conclusions, not missing user product information. Retire branch-sync unequivocally because its chain conflicts with main-only topology. Inspect actual contexts before replacing validate-pull-request and do not loosen merge gates.

Research artifact completes only local research responsibilities. #65 implementation, fresh CI, delivery, tracker closure and the root all-open-issue goal remain incomplete.
