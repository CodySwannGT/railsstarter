# #74 scoped release artifact implementation

Work-Item: CodySwannGT/railsstarter#74

Builder actor `01a10965-dbb8-7b40-a204-d3081a92b3f0`, native `/root/release_builder`, continued existing coordinator `01a1093f-be11-7262-9197-193444dff09a`. Branch `codex/74-release-deploy-input-resolution`; unchanged committed base `d8e2d726eb4889bcae93c1960991fb9cd482715d`. Canonical context was read fully, including every authored comment and inventory. Historical hold and direct-session claim remain intact. Plan, roster, full research, host rules/wiki and bounded local learnings reports were consumed. No central raw learnings ledger was loaded.

The opt-in template keeps runs eligible with cancel-in-progress false and an explicit successful-release guard under !cancelled(). Immutable trigger checkout bootstraps the resolver. A real Git fetch supplies the branch tip, and one annotated environment tag must identify a release commit within trigger-to-tip first-parent ancestry. VERSION and release subject must agree with the provider tag namespace, and the released commit must directly succeed this trigger. Unavailable/unrelated/missing/ambiguous artifacts fail visibly. Ordinary branch advancement preserves replay identity; subsequent releases make old replay ambiguous and explicitly rejected. No provider SHA output was invented.

Exact release SHA drives checkout, image tags and OCI revision labels. Publication verifies each immutable local image's revision, unique repository digest and digest-to-image-ID equality before extracting web assets or registering ECS definitions. ECS registration remains digest-pinned and records release-sha/release-tag metadata. #61 bin/publish-assets, bin/deploy-staging, Dockerfiles and actual image verification workflow are unchanged. #65 template remains inert outside .github/workflows. No cloud write, dependency/config/trust change, staging/index change, commit, push, PR or tracker mutation was performed.

## Current frozen source

| File | SHA256 |
| --- | --- |
| templates/github/workflows/deploy-ecs.yml | 62d8e09b13772118ac92f09df70d26a29ab6c0c1a0a53482d20766074764e841 |
| bin/resolve-release-artifact | c4f3cb047ed3578ee2651e73121a4faa747e7a3290f3f499e4a11ddb0f090674 |
| spec/workflows/release_artifact_spec.rb | 152e826b52b1d1e5efd4bd3d16c30a3b57573c5938e6604d854121477dbd1fc5 |
| spec/deployment/asset_publication_spec.rb | 9edc4c6fdec05b1985d19b99d654a83d0979f3c1a28703d339e26dd6d59009f3 |
| spec/deployment/fixtures/deployment_cli.py | eaf95b2ed4c562f747e2051716ddf1c32a7dbe8056d5cc9208014d54b07f22f1 |
| spec/workflows/ci_migration_spec.rb | 5d6d9c9b68f7c17b6f24e9ca3459ce8ec5443e00817825994e6cbb3487fa3282 |

## Actual commands and observations

Existing dependency preflight: Ruby3.4.11 with GEM_PATH pointing narrowly to already installed Ruby3.4.8/3.4.11 gems, `bundle check` exit0. No installation or config edits. Missing rspec executable wrapper was resolved through the installed `RSpec::Core::Runner` API.

Standalone DB-free shell/Git harness (absolute paths, all three named files executed, no test exclusion/override/skip flags):

```sh
PATH=/Users/cody/.local/share/mise/installs/ruby/3.4.11/bin:/Users/cody/.local/share/mise/installs/node/22.22.0/bin:$PATH GEM_PATH=/Users/cody/.local/share/mise/installs/ruby/3.4.8/lib/ruby/gems/3.4.0:/Users/cody/.local/share/mise/installs/ruby/3.4.11/lib/ruby/gems/3.4.0 bundle exec ruby -e 'require "rspec/core"; Dir.chdir("tmp/74-build"); exit RSpec::Core::Runner.run(ARGV)' -- "$PWD/spec/workflows/release_artifact_spec.rb" "$PWD/spec/deployment/asset_publication_spec.rb" "$PWD/spec/workflows/ci_migration_spec.rb" --format documentation
```

Exit0, 57 examples, zero failures. Real disposable Git histories exercise actual source resolver/fetch and checkout guards. Actual rendered template build/publication/registration shell executes against explicitly synthetic Docker/AWS CLI protocol, recording checked-out source, build tags/labels, immutable extraction image, digest-pinned task payload and release metadata. Named concurrent-release/self-push control observes parsed GitHub policy locally, not hosted scheduling.

Named negative controls: failed-release/visible-outcome; branch-advancement/exact-source; replay/artifact-identity; missing/lightweight/duplicate/wrong-environment tags; wrong VERSION/subject; non-direct/unavailable/abbreviated/unrelated commits; wrong/missing revision; wrong repository; malformed/missing/ambiguous digest; wrong digest image ID. Actual publication snippets reject wrong revision/digest image before extraction/ECS. Existing #61 upload/manifest/symlink/cleanup/immutable extraction negatives remain passing.

Detector falsification: an isolated current-source copy deliberately changed cancellation to true, bypassed the release outcome and checkout SHA guards, switched image tag selection to trigger SHA, and removed image revision/digest-ID equality checks. The complete release harness ran 22 examples and failed nine named checks, exit1. This proves the newly guarded checks fail on their violated properties; it does not claim real Docker/AWS behavior. Mutant source hashes were captured before removing only this builder-owned copy.

Targeted RuboCop through installed `RuboCop::CLI.new.run(ARGV)`: three changed specs, zero offenses, exit0. Ruby YAML parse plus bash -n on all14 actual template shell steps, bash -n helper, Python fixture AST parse and git diff --check passed. Official action-pin findActionRefs/evaluateReference on inert template checked6refs, zero findings, exit0; ci_migration independently executes the same official gate and its mutable-action/missing-checker negatives. Frozen #65 byte detector remains literal and strict, with reviewed #74 normalized template digest52c2354e8d249ed58167ab158fcdf0a49ff4e692934861bc441e0228b7e17b38.

Root command limits are explicit: the root .rspec RSpec invocation of release+asset specs ran45examples/zero failures but exited2 at application SimpleCov line0% below80% (branch100%). The standalone shell/Git boundary loads its own required libraries from ignored scratch cwd; no threshold or root spec configuration changed. Whole-root official action-pin CLI exited1 for two untouched validate-pull-request.yml mutable refs, ruby/setup-ruby@v1 and SonarSource/sonarcloud-github-action@v4. These broader carrier/application gates are not claimed green.

## Evidence

Raw logs and manifest are ignored0600 under tmp/74-build. All disposable Git repositories/fixture directories were removed by ensure blocks; isolated mutant directory was removed after hash capture. Existing canonical binding/context and coordinator-owned ignored checker plumbing remain untouched. No source hashes changed during cleanup.

| Evidence | SHA256 |
| --- | --- |
| tmp/74-build/standalone-final.log | da3aad6364858b9ee0cbb823846aef14bf077809d0d75277ed133cd5ae6886ba |
| tmp/74-build/detector-mutant.log | b5b7064766f7159955d21c3e3bda7b05461f1c28e02065fa93ff4d6d31f29f96 |
| tmp/74-build/rubocop-final.log | 7eb6dfe1141150265b9ad8950f845ef708b94f2aadf04a4b3bda2ec75d1ffb77 |
| tmp/74-build/syntax.log | 958f18ef377f57396a69b75ca71130aa0815caf3fbc869635fc33e79ab0338cd |
| tmp/74-build/template-action-pins.json | 5ac44643ca5e3728f4e58732a4192a145da60395395d961bc0e2a00b51a5694c |
| tmp/74-build/action-pins.json | dc31dd70394a01ef2ed6c1cde463c792268b179b2ce7d4fb4002df355f070f9d |
| tmp/74-build/rspec-second.log | 86545a824d03ca71fc6d1bb283dece76056631812d5146b28ffd8fbc41d317ba |
| tmp/74-build/source-evidence-manifest.json | 651d23111fdde4bb24ec03e179dbe5d7f6edd5c1ff1d6c4052cf4cc6e5bdb259 |

Not established: hosted GitHub concurrency/scheduling or CI run IDs, real image construction/OCI registry/ECR digest readback, S3 upload, ECS mutation/service health, runtime deployment, full Rails suite/coverage, carrier CI readiness. Independent current-byte source/security review and a different actor's empirical verification are still required before root creates normal-hook donor commits. Parent #65 owns hosted/batched integration.

metadata.learnings: [{"kind":"mistake","note":"Initial synthetic fixture indentation and stdout-only guard assertions failed; corrected and reran actual negative detectors."},{"kind":"learning","note":"Installed RSpec/RuboCop libraries work through Ruby3.4.11 with existing3.4.8 gem path; executable wrappers and root application coverage are separate boundaries."}]
