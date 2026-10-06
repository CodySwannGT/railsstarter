# #74 independent local empirical verification

Work-Item: CodySwannGT/railsstarter#74

**PASS at the local CLI/template/artifact boundary.** Verifier `01a10971-e414-78f1-a1e9-a348c1935a4a` (`/root/release_verify`) is different from builder and source/security reviewer. Cwd `/Users/cody/.codex/worktrees/3234/65-ci-workflow-migration`, branch `codex/74-release-deploy-input-resolution`, committed HEAD/base `d8e2d726eb4889bcae93c1960991fb9cd482715d`. This observation covers uncommitted workingtree bytes below, not the contents of the committed base. Coordinator must reconcile identical bytes to the donor commit in the ignored runtime verdict after normal-hook commit.

Full canonical context consumed as bytes: 149870 bytes, ignored0600, SHA256 `659e5bb5881626a29b69d28a1bfa55b683472560875f249ee2af932301e40e77`. Authored #74/#60 bodies, every comment and trailing inventory consumed, including claim5985668650. Historical audit hold and honest automated claim remain intact. Plan, roster, research and builder receipt, AGENTS/host rules/wiki, and bounded per-leaf executable learnings were read. No raw central ledger loaded. Named verification specialist is absent from the actual catalog; roster records native default closest-role fallback. No duplicate claim, source edit, index/settings/binding change, dependencies, database/cloud write or project commit was performed by verifier.

## Commands and observed boundaries

With installed Ruby3.4.11/Node22.22.0 PATH and existing Ruby3.4.8 GEM_PATH injected only into each subprocess:

- `ruby -rrspec/core -e 'exit RSpec::Core::Runner.run(ARGV)'` with absolute current paths for all three complete files `spec/workflows/release_artifact_spec.rb`, `spec/deployment/asset_publication_spec.rb`, `spec/workflows/ci_migration_spec.rb`, `--format documentation`, cwd ignored `tmp/74-verify`: exit0, **57 examples, zero failures**. No examples excluded and no root config/threshold change. This standalone harness does not establish Rails application coverage.
- `python3 tmp/74-verify/empirical.py`: exit0, **26 independent controls**. Actual current helper and template shell run against a real disposable Git history/local fetch remote. Annotated release is selected despite advanced branch HEAD; replay stays identical after ordinary advancement and rejects a second eligible released artifact. Failed/skipped/cancelled release, wrong checkout/tag, unavailable/abbreviated/unrelated/missing source and wrong revision/repository/malformed/missing/ambiguous digest/digest-image-ID fail visibly. Actual rendered build/publication/registration snippets record exact checkout source, selected-SHA tags and OCI labels, immutable web extraction ID, digest-pinned web/worker task payloads, release-sha/release-tag ECS metadata and publication before registration. Docker/AWS are explicitly synthetic protocol fixtures, not live required APIs or cloud proof.
- `python3 tmp/74-verify/falsify.py`: own isolated current-source copy sets cancellation true, bypasses outcome/checkout/revision/digest-ID guards and uses trigger image tags. The **complete** release harness runs22examples and fails9 named guarded-property examples, exit1 as expected. Actual baseline bytes were not mutated. Wrong cancellation, outcome, source, image revision/digest identity and trigger-image selection are detected. Wrong source/replay/digest protocol cases also reject through independent actual CLI controls.
- `ruby -rrubocop -e 'exit RuboCop::CLI.new.run(ARGV)'` on three changed specs: exit0,3files0offenses. `bash -n bin/resolve-release-artifact`, Ruby YAML plus `bash -n` all14 rendered template shell steps, Python AST parse current fixture and `git diff --check`: pass. Named ci_migration executes the shipped official action-pin detector on inert template and its deliberate mutable-action/missing-checker negatives.

Named `concurrent-release/self-push` observes the current parsed cancel policy with local event-state control and its cancelling-policy mutation. It establishes template eligibility policy only, not actual hosted scheduler behavior. Wrong artifact/source/guard checks fail deliberately; no unconditional fixture success is counted as external API evidence.

## Exact current source and evidence

| Source | SHA256 |
| --- | --- |
| bin/resolve-release-artifact | c4f3cb047ed3578ee2651e73121a4faa747e7a3290f3f499e4a11ddb0f090674 |
| templates/github/workflows/deploy-ecs.yml | 62d8e09b13772118ac92f09df70d26a29ab6c0c1a0a53482d20766074764e841 |
| spec/workflows/release_artifact_spec.rb | 152e826b52b1d1e5efd4bd3d16c30a3b57573c5938e6604d854121477dbd1fc5 |
| spec/deployment/asset_publication_spec.rb | 9edc4c6fdec05b1985d19b99d654a83d0979f3c1a28703d339e26dd6d59009f3 |
| spec/deployment/fixtures/deployment_cli.py | eaf95b2ed4c562f747e2051716ddf1c32a7dbe8056d5cc9208014d54b07f22f1 |
| spec/workflows/ci_migration_spec.rb | 5d6d9c9b68f7c17b6f24e9ca3459ce8ec5443e00817825994e6cbb3487fa3282 |
| bin/publish-assets (preserved) | e3caa50531779614d56b9c33ef092f4392a4eac3b45ec916d9f616306d937319 |
| bin/deploy-staging (preserved) | 3127df8161a7865b5245b45e91f19d37bb6f15e11e955808c650cd42027f992b |

| Evidence | SHA256 |
| --- | --- |
| tmp/74-verify/empirical.json | e691c87c8e9981d8cb584d45ac4d5c224cea18ebbeb4c63272d26dc88974e3c8 |
| tmp/74-verify/standalone-specs.log | 6a81c878588e821af7c92b16dbd2af271b0c55b1620116c9a0717a17f1e81aee |
| tmp/74-verify/falsification.log | 30ba64cb4ac07b3011e8561f5d51076acca727da698e12f4438f588cf08c0201 |
| tmp/74-verify/quality.json | e2c9c58e6257d2b942eff8ec709fe022a263fe0ea8edd793202dba1e6b2ad49e |
| tmp/74-verify/source-evidence-manifest.json | 9733c58c1b1d4286478c04b79c5cf2dc3f8b3d485f5f58d72b0086d9559a8a0c |

Ignored0600 empirical/falsification driver scripts, structured results and complete raw logs are retained only under verifier-owned `tmp/74-verify`. Real disposable Git repositories and mutant copies were removed by TemporaryDirectory. Actual tests' fixture directories are removed by ensure. No live cloud resources were created. Source hashes before/after cleanup agree. Canonical context and binding remain untouched.

Schema-v2 `.lisa/verification-status.json` was absent and proven ignored before creation, mode0600. It binds current workingtree hashes explicitly to observed base HEAD pending donor reconciliation. CLI claims cite cli-output, code-unit claims cite test-run-log; every evidence reference/hash/identity resolves, all claims carry limits, not_established_reviewed=true. Local scoped verdict passes, not full lifecycle completion.

Not established: hosted GitHub concurrency/scheduling or CI run IDs, real Docker construction/OCI/ECR readback, live S3 publication/ECS mutations/service health/runtime deployment, full Rails suite/coverage, globally green carrier CI, PR/merge/release/delivery. Builder's root .rspec invocation exited2 at Rails line0% below80%; whole-root official action checker exited1 on two untouched mutable validate-pull-request.yml refs. These are explicit integration gaps, not green gates. Parent #65 owns hosted/batch integration.

metadata.learnings: [{"kind":"learning","note":"Local parsed concurrency policy and real Git source replay can be proved separately from synthetic Docker/AWS artifact orchestration and hosted scheduling."}]
