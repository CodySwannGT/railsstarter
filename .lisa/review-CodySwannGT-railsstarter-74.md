# #74 independent current-byte source/security review

Work-Item: CodySwannGT/railsstarter#74

**GO for the scoped local donor source.** Reviewer `01a10971-7ed5-7373-af42-0c7711c42dde`, native `/root/release_review`, did not implement the change. No blocking source/security finding. Independent empirical verification remains a separate pre-commit prerequisite. This verdict covers only the exact product/test bytes below.

Cwd `/Users/cody/.codex/worktrees/3234/65-ci-workflow-migration`, branch `codex/74-release-deploy-input-resolution`, HEAD/base `d8e2d726eb4889bcae93c1960991fb9cd482715d`, parent `13d473318d32837fcf8e925250ecc5cd8c18132f`. Full canonical context read as 149870 bytes, mode0600 and ignored, SHA256 `659e5bb5881626a29b69d28a1bfa55b683472560875f249ee2af932301e40e77`. Every authored body/comment and trailing inventory were consumed. Historical hold, honest automated claim and separate parent coordination scope remain preserved. Plan, roster, research, builder receipt, host rules/wiki and relevant bounded learnings were consulted. No raw central ledger was loaded.

The actual pinned release workflow runs standard-version@9 with tag creation separated from the version commit. Current `.versionrc` selects plain-text VERSION for both input and bump, with no subject/lifecycle overrides. Installed standard-version9.5.0 confirms `chore(release): {{currentTag}}` and one commit lifecycle. Provider branch flattening and production namespaces match the helper. Full SHA availability, trigger-to-tip ancestry, first-parent release interval, annotated tag, VERSION/subject consistency, exact direct successor and unique candidate are checked before exposing the source. Ordinary advancement keeps the chosen release; absent/newly ambiguous replay stops explicitly. Promotion/no-new-artifact success also stops. Second full-depth immutable checkout checks HEAD and tag against the resolved SHA; lost helper/tag would fail visibly.

Cancel-in-progress false preserves the active original run under the locally observed policy. The !cancelled() job condition permits the explicit first-step outcome guard to report failed/skipped release; release-push deploy remains ineligible. This is policy review, not a hosted scheduler guarantee.

Build source is checked before build. Both image tags and OCI revisions use RELEASE_SHA. Publication validates full immutable image ID, matching revision, unique repository digest, valid digest syntax and digest-to-image-ID equality before web extraction or ECS registration. Actual shell consumes quoted validated SHA/tag values. The generated environment/output values are restricted to hex SHA and the validated numeric/environment tag namespace, preventing newline or shell injection in newly introduced output plumbing. The helper introduces no credential reads, logs or image-build secrets. #61 publication still extracts the immutable web image without entrypoint execution and precedes digest-pinned ECS registrations with release metadata. Existing asset manifest/symlink/failure/cleanup negatives remain intact.

#65 remains an opt-in inert template outside `.github/workflows`. The frozen normalized byte detector is a new literal reviewed #74 digest; action pin and missing-checker detectors remain strict. Existing publish-assets/deploy-staging, Dockerfiles and dockerignore bytes equal HEAD. No dependencies, thresholds, guards, config, bindings or index were changed by this reviewer.

New tests invoke real Git and actual helper/template shell. Docker/AWS protocol fixtures are explicitly synthetic; wrong revision/digest cases reach the executable guard before extraction/ECS. The cancel control is a parsed-policy model, and its final trigger-selection comparison alone is a static assertion. Builder mutant evidence and independent verifier falsifications are required for property sensitivity; neither creates hosted/cloud proof.

Known broader gate limits are not erased: root .rspec ran its named examples but exit2 on application SimpleCov0%/80%; whole-root action-pin CLI exit1 on two untouched mutable validate-pull-request refs. Standalone three-spec57-example success is the relevant DB-free boundary, not full application coverage or a globally green carrier. No new skip, ignore or weakened threshold is introduced.

| Source | SHA256 |
| --- | --- |
| bin/resolve-release-artifact | c4f3cb047ed3578ee2651e73121a4faa747e7a3290f3f499e4a11ddb0f090674 |
| templates/github/workflows/deploy-ecs.yml | 62d8e09b13772118ac92f09df70d26a29ab6c0c1a0a53482d20766074764e841 |
| spec/workflows/release_artifact_spec.rb | 152e826b52b1d1e5efd4bd3d16c30a3b57573c5938e6604d854121477dbd1fc5 |
| spec/deployment/fixtures/deployment_cli.py | eaf95b2ed4c562f747e2051716ddf1c32a7dbe8056d5cc9208014d54b07f22f1 |
| spec/deployment/asset_publication_spec.rb | 9edc4c6fdec05b1985d19b99d654a83d0979f3c1a28703d339e26dd6d59009f3 |
| spec/workflows/ci_migration_spec.rb | 5d6d9c9b68f7c17b6f24e9ca3459ce8ec5443e00817825994e6cbb3487fa3282 |

Review manifest `tmp/74-review/source-review.json` is ignored0600, SHA256 `f6c2ecd03f7debe41f9cb768a110923798f7772ee8bfed61bea53046fe96484c`. Reviewer ran `git diff --check` (exit0), checked unchanged protected source against HEAD and read current full source/tests. Raw manifest holds source hashes and no credentials.

Not established: hosted GitHub scheduling or CI run IDs, real container construction/registry digest readback, ECR/S3/ECS behavior or service health, full Rails coverage, cloud deployment, merge/delivery. Parent #65 owns integration. The donor coordinator must recheck these hashes and obtain the different verifier actor's empirical verdict before normal-hook commit.

metadata.learnings: []
