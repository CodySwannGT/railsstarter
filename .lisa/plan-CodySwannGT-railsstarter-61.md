# Credential-free builds and separate asset publication

Work item: CodySwannGT/railsstarter#61. Context: `/Users/cody/workspace/railsstarter/.lisa/work-item-context.md` (read in full). Roster: `.lisa/roster/CodySwannGT-railsstarter-61.md`.

## Authorization and inputs

Comment inventory: 2026-10-03T14:23:46Z historical withheld implementation (constraint); 15:57:48Z transparent recording of the user's new all-open-issues implementation authorization (decision/constraint); 15:57:56Z live Lisa claim (decision). The historical hold remains as history. Direct current user authorization takes precedence; no trusted actor policy or human-authored tracker release was fabricated.

Flow: Build/Task. Target environment assumption: dev; current `.lisa.config.json` maps dev to main. Remote main exists and equals local HEAD at 31517fd9aa0c4baf3e5eaecc3d9f7b4c5f271a44 after fetch. Feature branch: codex/61-credential-free-builds, PR target main. No permanent dev or staging branch is created. Existing dirty Lisa upgrade and audit artifacts are preserved; unrelated changes will not be swept into a credential-fix commit.

## Completion condition

With no deployment credentials passed to either build, actual web and worker Docker images build successfully. A synthetic credential sentinel deliberately added to an isolated build context cannot be found in either exported image's files or layers. A standalone CLI extracts compiled assets from the exact web image ID selected for deployment and uploads them before any ECS service update. Under an intentionally failing publication fixture, the deployment entry point exits nonzero and issues zero ECS service updates. Temporary extraction containers/directories are cleaned on success and failure. Historical image/credential assessment remains an operator follow-up, and no live AWS changes are required or authorized by this ticket's acceptance journey.

## Required access preflight

- GitHub repository and tracker: live #61/parent/context read and source-specific `gh api repos/CodySwannGT/railsstarter/contents/Dockerfile` succeeded.
- Local Docker daemon: `docker version --format '{{json .}}'` returned both client and Linux server 29.2.1 successfully. Actual container image construction/export will provide image evidence.
- Ruby/Bundler: Ruby 3.4.8 active and `bundle check` succeeded. RSpec is installed.
- Git: `git fetch origin main` succeeded; remote source proved current.
- Linux package/gem downloads: Docker Hub Ruby 3.4.8-slim manifest read succeeded (sha256:ff7780d9fc05a54690c722ee0621bae2aa818331be88ebbeb0f5e7bd7cdb7f37). The actual base, baseline worker, fixed web and fixed worker builds all completed with exit 0. Build logs are `/tmp/railsstarter-61-base-build.log`, `/tmp/railsstarter-61-before-worker-build.log`, and `/tmp/railsstarter-61-after-{web,worker}-build.log`. An independent verifier is inspecting all layers and the real compiled assets. No inaccessible service is replaced by a mock.
- AWS: local deployment and CI behavior are exercised with deliberately authored synthetic CLI fixtures as specified by the filed acceptance journey. Live AWS deployment, bucket access and credentials are outside scope, and no real service access is being claimed.
- UI: no UI surface changes; inspect existing harness locations and record shell/container regression harness. No design-source or persistent-state contract obligation is introduced.

## Tasks and metadata

```json
[
  {
    "plan": "credential-free-builds",
    "type": "task",
    "acceptance_criteria": ["Images build without deployment credentials and contain no credential sentinel", "Failed asset publication prevents service replacement"],
    "relevant_documentation": "Explorer completed full source/history/boot research: Dockerfile context→final copy and build S3 publication; worker context→final copy; workflow root credentials; local BuildKit credential file; three AWS initializer callsites. Existing regression harness absent (spec contains helpers only); scoped RSpec/subprocess fixtures and real Docker builds are the highest practical shell/container observation. Pinned release workflow has no SHA output, reserved for #74. Codebase research completed before builder was assigned.",
    "work_item_context": "/Users/cody/workspace/railsstarter/.lisa/work-item-context.md",
    "testing_requirements": ["Actual Docker build/export sentinel inspection", "Standalone publication success, failure and cleanup", "Local deployment upload-before-ECS and no-update-on-failure regression"],
    "skills": ["lisa-implement", "lisa-track", "lisa-github-verify"],
    "learnings": [],
    "required_access": [{"tool":"GitHub","probe":"gh api repos/CodySwannGT/railsstarter/contents/Dockerfile","status":"pass"},{"tool":"Docker","probe":"docker version --format '{{json .}}'","status":"pass"},{"tool":"Bundler","probe":"bundle check","status":"pass"}],
    "verification": {"type":"cli-test","command":"Build both actual Dockerfiles with no AWS env/secret args, export image layers and scan a synthetic sentinel; run bin/publish-assets and bin/deploy-staging against intentional CLI fixtures","expected":"Both images build, zero sentinel matches, successful publication precedes updates, failed publication returns nonzero with zero updates"}
  }
]
```

Research precedes implementation. An independent security/quality reviewer checks exposure and command ordering. A separate verifier executes the required proof and writes the v2 verdict, distinguishing local artifact/CLI evidence from live deployment. Meaningful learning candidates go through the included judge and learner; an empty learning set is valid. The global goal remains all open issues and is not complete when this leaf lands.

## Current landing dependency

The historical pre-commit `bundler-audit check --update` failed on eight advisory matches across six gems. Starter #63 now supplies the independently reviewed scoped commit `508d0033e5feb97950782506375ce6bc1fe06306`, integrated through a normal merge on this branch. Its normal audit and commit gates passed with zero advisories. No guard bypass or duplicate remediation was used. Existing managed upgrade files remain separate from this credential-fix scope. Supported CI migration #65 and exact Linux AMD64 shipping-image proof remain delivery prerequisites.

## Review corrections and verification

The real image exposed Propshaft 1.3's object-valued manifest (`digested_path`, `integrity`), which the initial string-valued CLI fixture missed. The publisher now validates either that actual shape or the legacy string format. The revised fixtures went red with 29 examples and 10 failures, then green with all 29 passing. Independent actual Docker extraction and authored AWS upload checks matched all 29 compiled asset byte hashes; success returned 0, deliberate upload failure returned 42, and both removed temporary containers/directories.

Both final source-snapshot images built successfully, then independent verification inspected all 21 layers with zero credential/private-path findings. The immutable identities came from actual `docker image inspect`, not the build log's config digest. These observations establish the local acceptance behavior, not a shipping commit or remote deployment. The v2 verdict remains in progress until integration, exact committed-artifact identity, fresh CI, merge and tracker closeout.

Security review also proved the scanner missed a synthetic value stored only in a symlink target. The scanner now inspects raw layer bytes plus decoded entry names, link targets and PAX headers, including compressed layers. Nine authored exported-archive tests cover those metadata paths, lower-layer content hidden by whiteouts, ordinary file bytes, credential paths, AWS image environment and a clean control. Four were red before correction; all nine now pass. `Verify Deployment Images` runs those tests, builds both real images without credentials, exercises real compiled-asset publication and retains its logs/JSON evidence. Final committed-image proof will be rerun after #63 integration rather than treating earlier snapshots as shipping artifacts.

The #63 resolver initially could not write its foreign-tree context from the #61-rooted session. A normal `codex exec -C <claimed-worktree>` session, with guards/config intact and no bypass flags, verified its actual cwd and successfully completed the ignored context bundle. #63 was implemented and committed in that real working root with its separate binding. No worktree guard state, root #61 binding, or historical hold body was changed to obtain access.

The integrated local suite exposed an authored Docker-login fixture that returned without consuming `--password-stdin`, causing a scheduling-dependent producer `BrokenPipeError`. A bounded stream larger than pipe capacity proved the failure deterministically. The fixture now drains stdin before returning, without logging the password or changing production pipefail behavior. Its regression went red then green, and the integrated deployment/runtime suite passed 52 examples with zero failures. The nine raw image-layer scanner tests also passed. Evidence and exact source hashes: `/tmp/railsstarter-61-fixture-pipe-review.md`. These checks do not replace fresh CI or committed-image proof.
