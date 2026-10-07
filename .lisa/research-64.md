# Ruby patch alignment research — Railsstarter #64

Observed live on 2026-10-04. Research specialist scope is selection, official artifacts and native compatibility. This file contains sanitized conclusions and public source facts only. Research does not constitute installation, build, runtime acceptance or delivery.

## Resolved input and scope

The complete authored `.lisa/work-item-context.md` was processed in memory, with all 39 fenced JSON blocks decoded successfully and all 115 final comment-inventory entries accounted for. Identity: 2,129,251 bytes, SHA256 `6ffbf90e4f40f1ed659dca8a42882897a3003a548b0a4b5d086c4c4a3e92ae04`. Raw input remains exclusively in that ignored file. The primary technical approach calls for a currently verified supported Ruby 3.4 patch across declarations, lock metadata, mise, containers and RuboCop. Ruby 4 is separate.

Exact acceptance criteria, extracted from the primary authored criteria:

```gherkin
Scenario: Required successful outcome
  Given every project runtime declaration
  When local tools, CI and both production containers report Ruby versions
  Then they report the same selected 3.4 patch

Scenario: Boundary or failure outcome
  Given native extensions built for that patch
  When test boot and web/worker smoke checks run
  Then extensions load and no unsupported Ruby declaration remains
```

Historical hold language remains intact. Current authorization permits implementation, but root stops at stable local review handoff before commit/push/PR. #65 owns common Lisa adoption and CI migration. #85 owns broad tooling after upstream #4333. #62/upstream #4332 safe helper adoption is separate.

## Current supported patch and release review

Select **Ruby 3.4.11**, not by assuming the ticket's example. The live [official downloads page](https://www.ruby-lang.org/en/downloads/) lists 3.4.11 as the stable 3.4 release, and [official maintenance branches](https://www.ruby-lang.org/en/downloads/branches/) marks Ruby 3.4 under normal maintenance. [Release announcement](https://www.ruby-lang.org/en/news/2026/09/23/ruby-3-4-11-released/) dates it 2026-09-23 and describes a scheduled bugfix release. [Official release details](https://github.com/ruby/ruby/releases/tag/v3_4_11) include fiber/thread fixes, parser/encoding corrections and memory-safety bug corrections in arrays, strings and IO buffers. The list is generated and may omit commits.

[3.4.9](https://www.ruby-lang.org/en/news/2026/03/11/ruby-3-4-9-released/) included zlib CVE-2026-27820 remediation. [3.4.10](https://www.ruby-lang.org/en/news/2026/06/30/ruby-3-4-10-released/) updated bundled net-imap for security fixes. The [August resolv advisory](https://www.ruby-lang.org/en/news/2026/08/27/multiple-vulnerabilities-in-resolv/) addresses CVE-2026-80212/80213 and recommends resolv 0.7.2. [3.4.11 source](https://github.com/ruby/ruby/blob/v3_4_11/lib/resolv.rb) defines 0.7.2. The project lock does not separately pin resolv and pins net-imap 0.6.4.1. A Ruby upgrade alone does not prove all independently locked gems patched, so audit and observed loaded versions remain required.

[Official version header](https://github.com/ruby/ruby/blob/v3_4_11/version.h) declares patchlevel **137**. Candidate lock metadata is `ruby 3.4.11p137`, which must still be generated/read back under the actual selected runtime. Official tar.xz source SHA256 is `f79c6e789ce4f30f77c88a40b23b93e2547c512a843dc17db27ab1f5cc66f4e4` (16,712,500 bytes), and tar.gz SHA256 is `5c22be44524312b3d433d68739bcc530633b1da5ef8ba0afa0a37680da17d3de` (22,492,449 bytes).

## Official immutable Docker artifacts

The live [Docker Official Images library entry](https://github.com/docker-library/official-images/blob/master/library/ruby) maps `3.4.11-slim` and `3.4.11-slim-trixie` to `3.4/slim-trixie`, docker-library/ruby commit `3f45e4c352eff67a95e61c8aa0bec55deee5a8fc`. [The immutable Dockerfile source](https://github.com/docker-library/ruby/blob/3f45e4c352eff67a95e61c8aa0bec55deee5a8fc/3.4/slim-trixie/Dockerfile) compiles Ruby 3.4.11 using the official tar.xz SHA above on Debian trixie slim. Current `3.4.8-slim` also identifies trixie, so explicit slim-trixie keeps the distro family.

Registry read command (no image execution):

```sh
docker buildx imagetools inspect docker.io/library/ruby:3.4.11-slim
docker buildx imagetools inspect --raw docker.io/library/ruby:3.4.11-slim
docker buildx imagetools inspect docker.io/library/ruby:3.4.11-slim-trixie
```

Both aliases report the same OCI index, and hashing the raw index reproduces its advertised digest:

`docker.io/library/ruby:3.4.11-slim-trixie@sha256:4677fd16f2b54ef534d18b0e34e20a15726b62c203cb996fd70297a058864c60`

| Actual platform | Immutable image manifest |
| --- | --- |
| linux/amd64 | `sha256:018085be495d8b3b2222e525fe30fe51890312e0a3ec0f68711e4ecb9054ef1f` |
| linux/arm64/v8 | `sha256:e1ef2e7252b8ba2ef7b1aeb8ae7fa878d41b01a368980fbe474ea38393be7ca3` |
| linux/arm/v5 | `sha256:5e12eee014a2e244637d79c8ac630a7ae627bf40aaf58586b5b616da1bf1455b` |
| linux/arm/v7 | `sha256:9dafbefc1ac665197e02eed4fba8f82c6ebe15f5e4e04fc5781b384fed0bdae0` |
| linux/386 | `sha256:b2cc4178d60a58f169397380ea09a600a0ca1b8517fbd468301badacf3be971c` |
| linux/ppc64le | `sha256:4f8380490641e1f4bd5a8a37758146d98f4b6b809eeae0493b19d86423e4680e` |
| linux/riscv64 | `sha256:ca2e0ea57d0e50edd83685fc3a7265bc3ce44e71707b09876bab22f097fb28c9` |
| linux/s390x | `sha256:acad88665b08372b156880a446059cf3267a3eabf14ce3d425e9b6c753187f99` |

Unknown/unknown descriptors are attestations and are not runnable target platforms. Linux AMD64 and ARM64 image annotations both match the official Ruby commit and version, with creation timestamps 2026-09-23T18:25:10Z and 2026-09-23T18:25:16Z. Their Debian base digests are `sha256:7792b1f7702a86946cd518db72b6a407302c3e9bc1635634368b878189e8221c` and `sha256:da496358bd6934d2bd6a563a33176a2e50eff5490c54b4ac6fb051b69fef4071`, respectively. This identifies official base artifacts, not application build/runtime proof.

## Native compatibility evidence

Preserve **mysql2 0.5.7** and **bootsnap 1.22.0**, already locked. [mysql2 0.5.7 release](https://github.com/brianmario/mysql2/releases/tag/0.5.7) explicitly added Ruby 3.4 and MySQL 8.4 to CI. Its [tagged matrix](https://github.com/brianmario/mysql2/blob/0.5.7/.github/workflows/build.yml) includes Ruby 3.4/MySQL 8.4 on Ubuntu 24.04 and Ruby 3.4/MySQL 8.0 on Ubuntu 22.04. macOS entries are allowed failures, so they are not a promise of native macOS success. Its [gemspec](https://github.com/brianmario/mysql2/blob/0.5.7/mysql2.gemspec) permits Ruby >=2.0 and builds `ext/mysql2/extconf.rb`. The [maintainer documentation](https://github.com/brianmario/mysql2#installing) requires appropriate MySQL/MariaDB client headers/libraries.

[Bootsnap 1.22.0 tagged CI](https://github.com/rails/bootsnap/blob/v1.22.0/.github/workflows/ci.yaml) includes Ruby 3.4 on Ubuntu. Its [gemspec](https://github.com/rails/bootsnap/blob/v1.22.0/bootsnap.gemspec) permits Ruby >=2.6, builds `ext/bootsnap/extconf.rb` and depends on msgpack. Its [changelog](https://github.com/rails/bootsnap/blob/v1.22.0/CHANGELOG.md) records improved handling of an opendir crash, and prior patches added Ruby-version cache invalidation and QEMU cross-build handling. New patch/runtime proof must not reuse obsolete native artifacts or count caches as compatibility evidence.

These upstream declarations support trying the preserved locked versions. They do not substitute for compiling/loading mysql2 and bootsnap under Ruby 3.4.11 in this project. No selected-Ruby necessity to change those gem versions was found.

## Declarations and integration gaps

At research readback, HEAD was `35acfcfd6ee6cd8ff27b1605a38cf59ed12656d1`. Git ancestry probes for both this #61 head and #63 `508d0033e5feb97950782506375ce6bc1fe06306` succeeded. Gemfile already contains Rails ~>8.1.4 and lock retains the #63 targeted runtime graph. Preserve exact ancestry and graph except selected Ruby metadata unless real compatibility evidence requires review.

| Declaration | Before | Required scoped behavior |
| --- | --- | --- |
| Gemfile | ruby 3.4.8 | exact selected 3.4.11 |
| Gemfile.lock Ruby metadata | ruby 3.4.8p176 | actual 3.4.11p137 readback |
| .ruby-version / .mise.toml | 3.4.8 | 3.4.11 |
| Dockerfile / worker.Dockerfile | ARG 3.4.8, mutable version-slim base | selected 3.4.11 and verified index identity |
| Dockerfile.local / worker.Dockerfile.local | ARG 3.4.8 | selected 3.4.11 and coherent base |
| .rubocop.yml | TargetRubyVersion 3.4 | already correct minor target, keep 3.4 |
| validate-pull-request workflow | ruby-version .ruby-version | selected indirectly, #65 owns caller migration |

Required future probes (not performed by research): real selected-Ruby bundle install/check with targeted graph preservation, mysql2/bootsnap native load, Rails boot/eager load/request assertions with authored AWS SDK stubs, meaningful runtime specs, touched lint and dependency audit, web and worker production images each reporting Ruby 3.4.11 and native extensions. Actual strict production image harness must use freshly owned MySQL 8.4 with ownership/port/identity and four unique database names proved before Rails/helper/schema mutations. Existing #63 harness accepts only `railsstarter_63_smoke_` prefix: choose a unique #64-owned suffix inside it rather than weakening guard. Do not load unsafe rails_helper. Falsified version/native/runtime controls must fail and source/image outputs must match exact current hashes. Record Linux AMD64 shipping CI acceptance pending #65 and do not equate local ARM64 with shipping AMD64. No live AWS writes or deployment.

## Research-time source identities

These hashes are baseline research readbacks and must be compared again after implementation. They are not the final implementation identity.

| Path | SHA256 |
| --- | --- |
| `Gemfile` | `511f8a1ed3bf8329585313cf54db488fb2b0f4485eaa063adcba610feb2c74b2` |
| `Gemfile.lock` | `84d6cad64ac6ac5a36165966af55c04891bca3ab143b6da92b52f526f7088747` |
| `.ruby-version` | `66c0484047b4b71f7545bc0d80f2e1ef67c7cd627ca34b181b14d672a63d043b` |
| `.mise.toml` | `28be5746256a30ad2260da7d37244cc461f8963ce5d5a81ddce71b48f0ab6ef0` |
| `Dockerfile` | `8083d48a67cff92c52ecd1147273863c28ef4ec5cac6c9a813fa742957995863` |
| `worker.Dockerfile` | `905b50a72ba61a689a779e2cf3ef69ebe25e72b021d20b8894e4711b6909132e` |
| `Dockerfile.local` | `59e5fad309f5fed17b3699e450295ddd679d10b92577afbd04dd9fda04edf2a0` |
| `worker.Dockerfile.local` | `e29e481b48c6493bdff26fc61964d98d7b94094f8aa345e4f4f207457ca5e85b` |
| `.rubocop.yml` | `5da977f7ac17634ae6658edd273a4ab0f1b7641e9958d23147e493593964186a` |
| `spec/fixtures/runtime/smoke.rb` | `9108312af4c8f9bb493f8d7685f2708a77696cc233b382c12044424700bb6a5e` |
| `spec/fixtures/runtime/acceptance.json` | `262dbb487e4510d48f5e217bbe78a9a4b724a3087e5247d500ed6f135dfadf91` |
| `spec/runtime/dependency_smoke_spec.rb` | `380342fc9b1bc30073fecb27be2b68484c0de9aa7310a65657d58c85758fb058` |
