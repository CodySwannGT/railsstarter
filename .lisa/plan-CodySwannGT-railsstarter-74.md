# #74 local release/deploy artifact contract

Work-Item: CodySwannGT/railsstarter#74

Coordinator `01a1093f-be11-7262-9197-193444dff09a` resumes the accepted claim and binding on `codex/74-release-deploy-input-resolution`, carrier base `d8e2d726eb4889bcae93c1960991fb9cd482715d`, parent `13d473318d32837fcf8e925250ecc5cd8c18132f`. Main remains the sole integration branch. Parent #65 owns batch PR/hosted CI later.

Canonical context: `/Users/cody/.codex/worktrees/3234/65-ci-workflow-migration/.lisa/work-item-context.md`, fully read, ignored0600, 149870 bytes, SHA256 `659e5bb5881626a29b69d28a1bfa55b683472560875f249ee2af932301e40e77`. The roster is `.lisa/roster/CodySwannGT-railsstarter-74.md`.

Scope: keep release runs eligible across their own release push with cancel-in-progress false; preserve the outcome guard; resolve one available release SHA with ancestry validation; use that source for checkout, image identity, asset extraction and ECS metadata; reject mismatches visibly. Preserve #61 credential-free builds and bin/publish-assets behavior and #65 inert opt-in deployment template. No default deployment activation, unrelated managed changes, dependencies, database provisioning, cloud writes, push, PR, release or closure.

Comment obligations: #74 5970061700 (CodySwannGT, 2026-10-03T14:24:14Z, decision/constraint) records historical audit hold and no delivered fix; current operator authorization permits this local implementation while retaining that history. #74 5985668650 (CodySwannGT, 2026-10-04T23:39:17Z, decision/constraint) records honest direct Codex claim and no delivery result. #60 5970057524 (CodySwannGT, 2026-10-03T14:23:43Z, decision/constraint) establishes coordination-only parent and separate cross-repository scope. No credential or repro obligations in captured comments. No secrets in tracked artifacts or teammate prompts.

Effective completion: an independent CLI verifier observes the actual local source/artifact selection code and named release/replay/concurrency controls passing against current byte hashes, while deliberately wrong commit, image, digest, replay and cancel selections fail or expose the baseline defect. Commands and actual runnable harness are determined by research before builder starts. Local lint, syntax and scoped tests are prerequisites. Independent current-byte source/security GO and a different actor's empirical proof precede normal-hook scoped donor commits with Work-Item trailers.

Required access: local git, installed Node22.22.0 and appropriate syntax/harness tools; repository source access already proved by accepted resolver. Authored validation explicitly excludes live AWS/provider writes. Hosted CI run/image metadata is an integration obligation for #65, not a fabricated local result. Research must identify any genuinely required additional access and probe it before build. No overrides or trust/config changes.

Tasks carry metadata: skills=[lisa-implement], learnings=[], required_access=[], work_item_context=canonical path above, relevant_documentation=pending research, verification.type=cli-test. Research owns read-only source/harness discovery plus local baseline reproduction receipt. Builder owns only research-selected release/artifact files and meaningful regression controls. Reviewer owns current-byte source/security verdict. Different verifier owns empirical CLI evidence, negative controls and schema-v2 local verdict. Raw logs remain ignored0600; tracked receipts contain hashes, commands, outcomes, boundaries and not-established items only.

Not established: hosted GitHub scheduling, real CI run metadata, ECR upload, S3 publication, ECS revision/service health, or cloud deployment. Local donor handoff is non-terminal and keeps claim, binding and context.

Research handoff: `.lisa/research-CodySwannGT-railsstarter-74.md`, SHA256 `fbceb6ff87e1eac28164f736db0d6a04cbd6224b63ec8827575e7a81cbe7ad36`. Actual affected surface is inert `templates/github/workflows/deploy-ecs.yml`. Pinned release workflow at `995f533b00d9b8a60256096bf6d28940164cd893` has no caller outputs (real API read passed, request `EA93:204CF7:3A68E1C:C0B556F:6AC2E9E0`), so source selection must use available validated annotated release tags, not fabricated needs.release.outputs fields. Baseline reproduction `tmp/74-research/baseline.json` SHA256 `b725c351a6c31810729c2f1092f318d3e084d807a04f95dfe30f5de296e17464` exposed parsed-policy cancellation, branch advancement identity mismatch, replay mismatch and absent release guard.

Builder ownership: inert template; one bounded release/artifact helper; new DB-free regression harness; minimal #61 fixture adaptations retaining all existing negatives; literal frozen #65 template digest/provenance update retaining detector strictness. `bin/deploy-staging`, `bin/publish-assets`, Dockerfiles, executable workflow callers and unrelated settings remain outside ownership. Highest feasible proof is actual local Git resolver plus actual rendered template shell with explicit synthetic CLI protocol fixtures. Fixtures never establish required external API or cloud behavior. Run named release regression, asset_publication and ci_migration specs, changed-file syntax/lint, action pin check and diff check. Independent verifier must execute actual current code and property-specific falsifications, then bind receipt to source/evidence hashes. A successful release job with no release artifact must fail visibly unless an explicit tagged-trigger policy is implemented and independently tested.

## Shared task metadata and dispositions

The following shared metadata applies to each bounded task below. Task-specific proof and MLD are in its signed receipt.

```json
{
  "plan": "74-local-release-deploy-artifact-contract",
  "type": "bug",
  "acceptance_criteria": ["Self release push does not cancel eligible deployment", "Exact released source and immutable artifact identity agree or fail visibly"],
  "relevant_documentation": ".lisa/research-CodySwannGT-railsstarter-74.md and canonical authored context",
  "work_item_context": "/Users/cody/.codex/worktrees/3234/65-ci-workflow-migration/.lisa/work-item-context.md",
  "testing_requirements": ["Named standalone release_artifact, asset_publication and ci_migration specs execute", "Actual Git/template CLI identity proof and property-specific detector falsification", "Parent #65 later supplies hosted named execution and real image metadata"],
  "skills": ["lisa-implement"],
  "learnings": [],
  "required_access": [{"tool":"local git and installed Ruby/Node", "probe":"real disposable Git operations; Ruby YAML; bundle check", "status":"pass"}, {"tool":"pinned GitHub release workflow source", "probe":"real GitHub contents API request EA93:204CF7:3A68E1C:C0B556F:6AC2E9E0", "status":"pass"}],
  "verification": {"type":"cli-test", "command":"Execute actual bin/resolve-release-artifact and rendered template shell against disposable Git history and explicit CLI protocol fixtures", "expected":"Correct release identity preserved on replay/branch advancement; wrong or ambiguous selection exits nonzero before publication/ECS registration"}
}
```

Research: real source/API contract and baseline CLI defect evidence, completed. Builder: six scoped source files, 57 named examples pass; isolated mutant has 9 failures among 22 examples; syntax, scoped lint and template pin gate pass, completed. Reviewer: independent current-byte source/security GO required. Verifier: different actor's current-byte CLI proof required. Root: only after both independent gates, recheck exact hashes, stage the explicit owned file allowlist and normal-hook donor commit.

Broader gate observations remain unresolved: root RSpec invocation exited2 at Rails application line coverage0 below80 despite 45 shell/Git examples passing; whole-root action-pin check exited1 on two untouched mutable refs in validate-pull-request.yml. No tests excluded, detectors weakened, thresholds/settings changed or hosted results asserted. Temporary ignored official checker symlink is local execution plumbing, coordinator-owned and removed after proof; parent #65 retains responsibility for tracked common checker adoption/CI integration.

Pre-commit gate satisfied: independent reviewer `01a10971-7ed5-7373-af42-0c7711c42dde` GO; different verifier `01a10971-e414-78f1-a1e9-a348c1935a4a` PASS at local CLI/template/artifact boundary. Verifier executed 26 independent controls, all57 scoped examples, and nine expected failures among22 deliberate mutant examples. Current product and preserved hashes, evidence hashes/kinds/identities, ignored0600 context/logs, protected settings/source and empty index were independently read back by coordinator. Usage was captured once per six unique actors and canonically recorded as a measured subset, never a complete cost or final session total. Scoped normal-hook donor commit is the next authorized step, with binding/context retained for parent integration.

## Lisa Usage

_This section is managed by Lisa. Rewrites update matching usage entries in place and preserve older rows._

| Flow | Source | Model | Tokens | Cost |
| --- | --- | --- | ---: | ---: |
| lisa-implement | measured-subset | openai/runtime-default | 21094788 measured subset | null |

<!-- lisa:usage-entry entry_id=lisa-implement-74-01a1093f-be11-7262-9197-193444dff09a flow=lisa-implement run_id=01a1093f-be11-7262-9197-193444dff09a provider=openai model=runtime-default source=measured-subset input_tokens=20994281 cached_input_tokens=20317824 output_tokens=100507 reasoning_tokens=21172 total_tokens=null cost=null currency=null pricing_status=unavailable pricing_source=null artifact_ref=github%3ACodySwannGT%2Frailsstarter%2374 parent_artifact_ref=github%3ACodySwannGT%2Frailsstarter%2360 --> <!-- lisa:usage-entry-measured-subset entry_id=lisa-implement-74-01a1093f-be11-7262-9197-193444dff09a measured_subset_tokens=21094788 -->

<!-- lisa:usage-rollup direct_entry_ids=lisa-implement-74-01a1093f-be11-7262-9197-193444dff09a child_entry_ids= child_refs= direct_tokens=null child_tokens=null total_tokens=null direct_cost=null child_cost=null total_cost=null currency=null child_currency=null -->
