---
type: source
created: 2026-10-06
updated: 2026-10-06
related: [wiki/playbooks/onboarding.md]
sources: [README.md]
sensitivity: internal
source_system: docs
original_filename: README.md
source_sha256: 815bf3e982d5e2cbba5d8adf97f6f21c773d3dd5a81974f26ae13919b769d513
source_base: ba30a778702177dd78c970a7d46de0b26d8ed91a
source_status: uncommitted-source-aligned-instructions
---
# Setup and rename instructions from README

This sanitized note captures the updated README's source-supported instructions. It preserves the earlier 2026-10-05 note as historical provenance. No command execution, wiki verification, hook/provider acceptance or final issue completion is asserted here.

The source implementation is #70, shared-image/preparation #71/#72, and the assembled starter at `ba30a778702177dd78c970a7d46de0b26d8ed91a`, brought in through ordinary ancestry before this ingestion. Derive Node/Bun from the committed Lisa entry in package-lock.json and Bundler from Gemfile.lock rather than copying a dated release number. The consumer owns its first-setup-seeded CI caller and database inputs; Lisa owns the reusable workflow it calls.

## Developer setup

The README starts with a fresh standalone clone, chosen Ruby/display/package/database identities, and isolated ports. bin/setup refuses a linked worktree to protect shared hooks. Manual renaming covers the App module and corresponding references, public display/PWA, coherent package/lock identity, real GitHub/Lisa/wiki organization, database/Compose names, private application key and optional integration values. The SmokeConsumer library namespace belongs to the validation runner and remains unchanged.

Ruby is 3.4.11. Install the exact locked Node/Bun/Bundler, reachable Docker/Compose and host compiler/MySQL development libraries. Use Bun for project JavaScript dependencies. A private .env configures Compose's database host db; host Rails needs explicit TCP 127.0.0.1/3306 and the same database base/user. Non-root users need actual grants for all required schemas.

After healthy MySQL starts, bin/setup --skip-server validates exact tools, installs JavaScript dependencies, checks/installs Ruby's development bundle, installs Lefthook, prepares development and test databases and clears logs/temp files. It uses a present Bun lock frozen or requires an initial lock to be created. It checks unchanged dependency inputs and installed Lisa identity without applying templates. Without the flag it starts bin/dev, which runs web only.

Compose web, worker and db-prepare share one local image. Build web, run one-shot preparation and start web; named home and /up responses are the developer's checks. Application entry points do not independently migrate. MySQL is digest-pinned 8.4.11 with utf8mb4/utf8mb4_0900_ai_ci. For base D, physical databases are D, D_queue, D_cache and D_cable; tests append _test to each concern's name. The local replica shares the primary identity.

## Disposable validation and real contributions

bin/smoke-consumer --source HEAD --names acme_portal,acme_portal_two exports only committed source into two fresh consumers, chooses loopback ports, runs setup twice per consumer, starts genuine web/workers and checks renamed HTTP, native schemas and a consumed synthetic job. Its test-only SDK tripwire checks zero live AWS calls. Private evidence stays under ignored tmp/consumer-smoke/, with owned runtime cleanup. It does not create repositories/issues, apply templates or deploy.

HookEvidence checks installed executable Lefthook wrappers and hashes, not their gates. Functional work-item/provider hook verification uses a genuine tracker binding and ordinary commit/push. A conventional headline alone does not replace trailers or provider evidence. main is the sole permanent integration branch; short-lived contribution branches target it. Local smoke does not establish hosted CI or Linux AMD64 delivery.

## Generated and optional configuration

Rails owns the four generated schema files. Use native database tasks and inspect their output; task/environment controls dumping. Do not force schema class versions or blanket-autocorrect native schemas. Staging/production disable post-migration dumping.

Local onboarding needs no deployment credentials. Development/test bootstrap defaults off; disabling bootstrap does not disable the scheduled CloudWatch SDK call. Normal workers need selected scheduled integrations configured; offline smoke uses test-only fixtures. Optional telemetry requires an explicit service name when an exporter is enabled. Deployment host/ingress, trusted peers, mail/storage/Kamal/profiles/SSM/secrets/exports remain explicit owner-selected inputs, not inferred infrastructure. Ordinary staging/production uploads require their own nonblank ACTIVE_STORAGE_STAGING_BUCKET or ACTIVE_STORAGE_PRODUCTION_BUCKET and ACTIVE_STORAGE_S3_REGION, using runtime SDK/task-role credentials. These upload buckets are separate from compiled asset publication. Sonar project/organization and Dockerfile image/container names are explicit optional examples.

Image construction is credential-free. Separate publish-assets extracts compiled assets from a never-started image and syncs without deleting prior fingerprints. Deployment publishes before ECS update. Its dry-run still authenticates/discovers AWS and no-deploy still builds/pushes; neither is a local onboarding probe.

Source: README.md
