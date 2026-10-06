# #74 release artifact research

Work-Item: CodySwannGT/railsstarter#74

Research actor `01a1095f-eacf-7842-88b5-9dbd3d62249b` read the existing plan and roster before source inspection. Cwd `/Users/cody/.codex/worktrees/3234/65-ci-workflow-migration`, branch `codex/74-release-deploy-input-resolution`, committed HEAD/base `d8e2d726eb4889bcae93c1960991fb9cd482715d`. Canonical context fully consumed as bytes: 149870 bytes, mode0600, ignored, SHA256 `659e5bb5881626a29b69d28a1bfa55b683472560875f249ee2af932301e40e77`. Authored #74/#60 body, every comment and trailing inventory were inspected. Historical hold and honest direct-session provenance remain obligations, current operator authorization governs local work. No secret-bearing input was copied to this receipt.

Host AGENTS, project rules, wiki orientation/contract/index were read. Wiki index has no substantive release synthesis. No committed learnings ledger/projection was found by bounded filename inventory, so no raw ledger was loaded.

## Current contracts and baseline

Deployment remains opt-in at `templates/github/workflows/deploy-ecs.yml`. No `.github/workflows/deploy.yml` exists. The inert template still has `cancel-in-progress: true`, branch-name checkout and trigger `github.sha` tags. The issue's reported locally applied release-outcome guard is absent from these current bytes. The installed Lisa create-only deploy template has the explicit first-step `RELEASE_RESULT` guard and `!cancelled()` job condition needed to expose failed release instead of an implicit neutral skip.

#61 already captures local immutable web/worker image IDs, resolves exactly one matching repository digest, extracts assets by web image ID and registers digest-pinned ECS images. `bin/publish-assets` validates the manifest and rejects symlinks, uses private scratch, cleans stopped extraction containers and retains older fingerprints. Dockerfiles remain credential-free. Preserve these properties and publication-before-registration ordering. `bin/deploy-staging` uses local HEAD and existing digest capture, it has no release workflow transaction. Prefer keeping it unchanged for this template-specific defect unless executable research proves another authored mismatch.

Baseline CLI reproduction parsed the actual YAML with installed Ruby YAML/JSON and created a real disposable git history containing trigger → annotated release → ordinary branch advancement. Named local controls `concurrent-release/self-push`, `branch-advancement/exact-source-image`, `failed-release/visible-outcome` and `replay/artifact-identity` each exposed the pre-fix defect. Checkout selected the advanced branch commit while image tags recorded the trigger SHA. Cancellation result is a model of the parsed workflow policy, not hosted GitHub scheduling. The synthetic repository was removed. Evidence `tmp/74-research/baseline.json` is ignored0600, SHA256 `b725c351a6c31810729c2f1092f318d3e084d807a04f95dfe30f5de296e17464`.

## Actual pinned release provider contract

Fresh real `gh api --include repos/CodySwannGT/lisa/contents/.github/workflows/release-rails.yml?ref=995f533b00d9b8a60256096bf6d28940164cd893` returned HTTP200, request `EA93:204CF7:3A68E1C:C0B556F:6AC2E9E0`, blob `962b3306d68c5ccc3ba7cc5736adf42dbcdc0f63`. Workflow SHA256 `ef76c55fdcd7141a97de92ae6ddf018683e5489b28518a0944320b645a78c7f7`, raw API evidence SHA256 `43cb82b117b54cf43d84a5050e9b7f8d2468ca3555db5f2b0950901e09561b94`. Both files remain ignored0600 under `tmp/74-research`.

There are **no caller workflow outputs or release job outputs**. The version step exposes only `version` and `tag`, which are not caller outputs. Do not invent `needs.release.outputs.sha`. Actual behavior: checkout event commit, standard-version creates the release commit, VERSION remains clean, then an annotated tag is created and pushed with the branch. Main/master/prod/production use `v<VERSION>`. Other branches use `v<VERSION>-<branch flattened to A-Za-z0-9.->.<epoch>`. A conflicting existing tag on another commit fails. Main creates/reuses a GitHub Release. Successful reusable execution can skip versioning for `chore(release):` commits or detected promotion merges, so success alone does not prove a new release artifact.

## Smallest builder ownership and falsification

Own the inert template, one bounded release-artifact helper if needed, one new DB-free workflow regression spec/CLI fixture, and only the frozen template evidence expectation in `spec/workflows/ci_migration_spec.rb`. #65 currently asserts every template byte apart from action pins against digest `75adbb19152a04f14a2aa3a7166b0cffa3c286f4d2dcd947f1d2104a070e14c9`. Update that literal and its provenance/comment/test wording to the reviewed #74 template digest, preserving immutable pin gates, no executable default deploy detector and unchanged image-verification workflow digest. Do not weaken or remove this detector.

Set cancellation false, restore the shipped outcome guard first, bootstrap helpers from the immutable trigger checkout, resolve the intended released commit once using actual git metadata, then checkout that exact SHA. Validate full SHA syntax, object availability, trigger ancestry, release-commit identity and the correct annotated environment tag. Search only the eligible trigger-to-fetched-branch ancestry interval. Require an unambiguous release candidate. A later ordinary branch commit must never become the selected build source. Multiple eligible released commits/tags must fail explicitly rather than choose latest. Replaying the same triggering run must resolve the same artifact or fail closed on ambiguity. A release-commit push stays ineligible. A successful promotion/no-new-release run must fail with a specific missing-artifact reason unless a separately explicit, tested tagged-trigger policy applies. Do not silently fall back to branch HEAD or trigger SHA.

Use the selected SHA for checkout, OCI revision labels/image tag identity, extraction binding and ECS revision metadata. Existing image ID/digest publication semantics need a revision-label/expected-SHA check, and a repository-digest selection must reject wrong/ambiguous repository or digest. Tests should deliberately mutate cancellation, guard outcome, wrong commit, unrelated/unavailable source, branch replay ambiguity, wrong image revision and wrong/ambiguous digest. Each authored detector must fail its deliberate wrong-property fixture.

Existing runnable harness: `spec/deployment/asset_publication_spec.rb` executes actual template publication/ECS shell snippets with explicitly synthetic CLI protocol fixtures. It proves local orchestration/template artifact selection only, not ECR/ECS/S3 behavior. Extend or adapt fixtures only where needed, preserving the existing failure and extraction checks. A stronger DB-free release harness should invoke the actual resolver with real disposable git repositories and execute actual rendered build/artifact-selection template snippets. Run native RSpec named release specs plus asset_publication and ci_migration, targeted RuboCop, bash syntax on changed shell, Python syntax on changed fixture, official action-pin checker and `git diff --check`. Independent CLI verifier repeats actual helper/template commands against current hashes and negative controls.

## Source hashes at research handoff

| Path | SHA256 |
|---|---|
| templates/github/workflows/deploy-ecs.yml | b7f4e2f454c9a3ad097ca10ddc6e429f86bbaa6818bd20d97cda648ed3457d4e |
| bin/deploy-staging | 3127df8161a7865b5245b45e91f19d37bb6f15e11e955808c650cd42027f992b |
| bin/publish-assets | e3caa50531779614d56b9c33ef092f4392a4eac3b45ec916d9f616306d937319 |
| spec/workflows/ci_migration_spec.rb | 27a599c4c02c5ba197aa5add0b239b784ccbc388b3b419eeca259fd622bb2b73 |
| spec/deployment/asset_publication_spec.rb | 5521ed09a30a88f573fb98798005f66f52e9d4429906dea55aab1272689b0f81 |
| spec/deployment/fixtures/deployment_cli.py | 78bbf3a4c79ff96270c1966e7f077f3661df2b676723e0759d8422633aba57a6 |

`metadata.required_access`: local git and installed Ruby YAML passed, fresh real GitHub source API passed. Direct installed Ruby3.4.11 `require rspec/core` did not find gems without the existing bundle environment. Parent must resolve the already-installed bundle environment before RSpec, without dependencies/config/trust changes. Live AWS is explicitly outside authored local validation and is not required. Actual hosted CI run IDs/commit/image metadata remain #65 integration evidence obligations, not locally established facts.

`metadata.learnings`: [{"kind":"learning","note":"Pinned release-rails workflow exposes no caller SHA/tag outputs and successful skip is distinct from cutting a release.","evidence":"tmp/74-research/pinned-release-rails.yml"}]

Not established: hosted workflow concurrency, actual CI execution metadata, ECR artifact upload/readback, S3 publication, ECS task/service health, deployed runtime. No product source edited, project commit, claim mutation or cloud writes performed by this research actor.
