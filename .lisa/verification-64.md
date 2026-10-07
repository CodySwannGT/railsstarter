# Independent local verification — Railsstarter #64

Stable local handoff for parent review. Full #64 acceptance remains in progress. No commit, push, PR, merge, tracker closure, context clear or binding clear was performed by this verifier.

## Identity and independence

Native cwd `/Users/cody/.codex/worktrees/a5d8/railsstarter`, branch `task/64-align-ruby-3.4-patch`, HEAD `35acfcfd6ee6cd8ff27b1605a38cf59ed12656d1`, merge-base/main `31517fd9aa0c4baf3e5eaecc3d9f7b4c5f271a44`. Exact #61 and #63 ancestors were independently verified. HEAD does not contain the new uncommitted implementation. V2 artifact identity therefore supplements HEAD with dirty-source manifests and final immutable image IDs.

Verifier independently reviewed declaration and runtime diffs, locked graph preservation, spec meaning, exact native binaries, observed image/runtime outputs and negative controls. Builder owns declarations and bundle installation. Verifier owns the runtime fixture extension, four added examples, reports and task-owned evidence/resources. Historical hold/provenance and original strict harness safety checks remain intact. Complete ignored input processed: 2,129,251 bytes / SHA256 `6ffbf90e4f40f1ed659dca8a42882897a3003a548b0a4b5d086c4c4a3e92ae04`, all 25,856 lines including final inventory. No raw input text was copied into evidence.

## Actual results

| Proof | Observation |
| --- | --- |
| Baseline explicit host Ruby | 3.4.8; bundle check, actual mysql2/bootsnap native loads, strict authored SDK boot/eager-load/home/health PASS |
| Selected isolated bundle | Builder fresh install55 dependencies236 gems and check PASS, then independent bundle check PASS under actual Ruby3.4.11p137 |
| Selected host actual runtime | mysql2 0.5.7 and bootsnap1.22.0 freshly compiled native `.bundle` files loaded, actual Rails boot/eager-load/home/health200 PASS |
| Owned MySQL8.4 host runtime | Four positively identified fresh databases, schemas loaded and exact native-adapter reads PASS |
| Targeted RSpec | Final real-cwd26 examples,0 failures; old suite22 plus4 new meaningful examples; unsafe `rails_helper` never loaded |
| Scoped lint | Gemfile and3 owned runtime Ruby files:4 inspected, no offenses, exit0 |
| Standard full lint | Actual `bundle exec rubocop`:48 files,1 unchanged `db/schema.rb:3 Lint/EmptyBlock`, exit1. Nonpassing, no ignore/threshold/config change. Config/cwd/exclusion diagnostic retained |
| Dependency audit | `bundler-audit check --update`:1252 advisories, commit97659622944c19d42961c03813666f4196457229, no vulnerabilities, exit0 |
| Production web AND worker images | Real Dockerfile builds on Linux ARM64, actual3.4.11p137 / aarch64-linux / mysql2 .so0.5.7 / bootsnap .so1.22.0, exit0 |
| Strict production runtime in BOTH images | Complete deployment runtime bundle, authored SSM/SecretsManager fixtures consumed, Rails production boot/eager-load, four isolated MySQL8.4 schemas/read results, GET `/` and `/up`200 with expected content, exit0 |
| Source identity | BOTH images exactly match all89 runtime input hashes, including boot/config/schema/fixture sources. Independent final source/evidence digest readback PASS |
| Final cleanup | Only positively owned MySQL container and its identified anonymous volume removed; terminal absent, zero remaining owned containers, port closed. Tagged application images retained |

Host native MySQL client9.6.0 is distinct from positively observed server8.4.11. Server compatibility was empirically tested through actual connections and schema/read operations. Production images emitted the pre-existing optional image_processing warning. Image variant processing is not established by home/health smoke.

## Exact commands and immutable artifacts

Full exact argv, working directory, timestamps, exits, observed expected failures and log identities are retained in `evidence/64/commands.json`. Large build logs remain in the unique proof root named by ignored `.lisa/proof-root-64.json`. Builder activated command details remain in `.lisa/implementation-64.md` and its unique builder root.

Host prefix uses the explicitly installed3.4.11 Ruby and RubyGems Bundler2.4.10 wrapper, with the authored isolated environment from `/tmp/railsstarter-64-builder-a4d52vq5/ruby-bundle-env.json`:

```text
/tmp/railsstarter-64-builder-a4d52vq5/mise-data/installs/ruby/3.4.11/bin/ruby
/tmp/railsstarter-64-builder-a4d52vq5/bundler-tools/bin/bundle
```

Suffix commands observed: `check`, `exec rspec spec/runtime/dependency_smoke_spec.rb spec/runtime/dependency_smoke_ruby_spec.rb`, `exec rubocop spec/fixtures/runtime/smoke.rb spec/runtime/dependency_smoke_spec.rb spec/runtime/dependency_smoke_ruby_spec.rb Gemfile`, `exec rubocop`, `exec bundler-audit check --update`, `exec ruby spec/fixtures/runtime/smoke.rb` with explicit task-owned database environment or DB-free test mode.

Build argv: `docker build --platform linux/arm64 --progress=plain --label lisa.owner=railsstarter-64-01a10731 --label lisa.work-item=railsstarter-64 -f <Dockerfile|worker.Dockerfile> -t <tag> .`. Strict production invocation overrides entrypoint to `ruby`, activates the real production bundle with `-rbundler/setup`, then runs `spec/fixtures/runtime/smoke.rb`, with explicit production/image/DB flags and only authored credentials.

| Image | Retained tag | Immutable final ID |
| --- | --- | --- |
| Web | railsstarter-64-web:rlemukl0 | sha256:21a17cf3c463f6e8d5265794ac59918b809e08ce80bb01e5afa82a673e436f28 |
| Worker | railsstarter-64-worker:rlemukl0 | sha256:08cec11f5162ec93006c7e0489529f1b4bfa82d5b7867ca21c7315dccc2026e7 |

Both final images are Linux ARM64. Official base index is `sha256:4677fd16f2b54ef534d18b0e34e20a15726b62c203cb996fd70297a058864c60`. Official platform manifests were separately researched, not mistaken for application delivery.

Declaration/spec source manifest SHA256 `0195ed9ff659f558c3f696848421a2025a42685ad034b4e5744ad285e129ea34`. Runtime89-file manifest SHA256 `0cf7fdc3451031477e6837ee5740131605f91f597871f28f0d0fd33fd1a977bb`. Files and hashes are retained in `evidence/64/final-source-manifest.json` and `runtime-source-manifest.json`. Original first builds were superseded after narrow owned lint corrections; only final rebuilt IDs carry final proof.

## Owned database preflight and cleanup

Fresh container ID `e266622a2da8c274d489494946549e03da36ee4d84a46e6ae519188d172e36e2`, name `railsstarter-64-mysql-rlemukl0`, owner label `railsstarter-64-01a10731`, immutable MySQL image `sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242`, observed server8.4.11. Host published port `127.0.0.1:50456` to container3306, with image harness explicitly targeting host.docker.internal:50456. ID/label/image/port and all12 task-unique empty database identities were proven before Rails/schema operations.

Unique bases: `railsstarter_63_smoke_64rlemukl0host`, `railsstarter_63_smoke_64rlemukl0web`, `railsstarter_63_smoke_64rlemukl0worker`. Host has `_test`, `_queue_test`, `_cache_test`, `_cable_test`. Image quartets are base primary plus `_queue`, `_cache`, `_cable`. Each preflight SELECT reports actual database/version/hostname/port and0 tables. Final direct queries independently observed primary metadata2 rows, queue/cache/cable0 rows across all3 lanes.

Before cleanup, exact current container identity and attached volume `d6f2657c3007b592b1e13d811846ef476355ebb51ccf9a0f3853f00f2b4dd6ee` ownership were revalidated. `docker rm -f -v <exact-owned-ID>` removed only these resources. Subsequent inspect proves container and volume absent, task-label inventory empty and50456 closed. No sibling resource, shared network or unrelated scratch was deleted. Proof/build/runtime/source snapshot directories remain local for parent review.

## Codified verification and falsification

The existing strict runtime acceptance harness now observes actual interpreter/declaration/verified-release coherence and native-extension paths/content hashes after actual application boot. Its existing endpoint/schema/SDK acceptance assertions still decide actual production image behavior. `spec/runtime/dependency_smoke_spec.rb` adds actual booted native checks. `spec/runtime/dependency_smoke_ruby_spec.rb` adds3 host declaration/interpreter/lock/digest/minor checks. Files use configured native RSpec discovery, no new framework. Shipping-image invocation belongs in #65's single CI integration.

| Real deliberate break | Observed failure |
| --- | --- |
| Private-copy Dockerfile index replaced with64 `f` digits | New coherence spec failed and localized Dockerfile, exit1 |
| Private-copy `.ruby-version`3.4.8 | New interpreter spec failed3.4.11 vs3.4.8, actual host harness also rejected after boot, exit1 |
| Private-copy `/up` expected201 | Actual Rack GET returned200, harness rejected `Unexpected response for /up: 200`, exit1 |
| BOTH final image `.ruby-version` read-only overlay3.4.8 | Actual image boot reached runtime assertion, observed3.4.11 vsdeclared3.4.8, exit1 |
| BOTH final image actual mysql2 `.so` replaced with empty read-only overlay | Actual native require failed at named mysql2 binary with `file too short`, exit1 |
| BOTH final image actual bootsnap `.so` replaced with empty read-only overlay | Actual boot native require failed at named bootsnap binary with `file too short`, exit1 |
| BOTH final image authored SSM response replaced | Actual SDK/config boot rejected unconsumed authored fixture, exit1 |

Controls never changed the shared source, installed shared gems, guards or declarations. Mounts belonged to disposable labeled containers. Each image's positive final strict smoke succeeded after removal of all control overlays. Restored private-copy specs26/26 and real-cwd final specs26/26 passed. Original22 safety examples remain prerequisites, not substitutes for actual image/runtime evidence.

Two instrumentation issues are preserved rather than counted as software/control failures: raw Bundler gem exe could load duplicate default Bundler on macOS; installed RubyGems wrapper resolves correct2.4.10 activation. Plain image Ruby lacked Bundler activation before authored SDK require; `ruby -rbundler/setup` resolves this with the real production bundle. Schema loader writes stdout before the result JSON, so collection decodes the explicit runtime_smoke_result record without rerunning against nonempty databases.

## Not established

- Final Linux AMD64 application build/runtime/shipping CI and CI declaration output remain pending #65. Linux ARM64 proof and official AMD64 base identities do not establish AMD64 delivery.
- Full configured lint is not passing on the unchanged schema. Full specs using the unsafe ambient helper were not run. No exclusions or thresholds were weakened.
- No commit/PR/merge, deployed health, public network HTTP transport, live AWS, live application databases, worker job drain or image variant processing was exercised. Strict HTTP transcripts explicitly identify in-process Rack requests against the actual app.
- #62/upstream #4332 safe-helper adoption, #65 common Lisa adoption/caller migration and #85 broad tooling remain separate tracked lanes.

`.lisa/verification-status.json` schema2 is ignored as proven before writing and status `in_progress`, not full pass. Tracked compact `evidence/64/verdict.json` has established local boundaries plus required not-established CI/AMD64 claim. Claim/evidence mapping follows installed Lisa contracts. Final digest/source verification is `evidence/64/independent-readback.json`.

## Small implementation lessons

- Invoke Bundler through its installed RubyGems wrapper when an older lock-pinned Bundler coexists with Ruby's default Bundler.
- Activate the production bundle before the standalone authored SDK harness in a final image.
- Prove named fresh MySQL resources and every database before Rails load; collect final schema-loader JSON without destructive reruns.
- Retain source hashes alongside unchanged HEAD when review handoff deliberately stops before commit.
