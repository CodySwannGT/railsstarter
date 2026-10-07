# Bootstrap CDN research for railsstarter #81

Research-only handoff, 2026-10-04. No implementation, branch, tracker, runtime or dependency-tree mutations were performed by this specialist. Root integrated the existing #65 commit separately after this research established ancestry. Delivery remains in progress and must stop before commit/push/PR for root review.

## Identity, scope and complete inputs

Native research specialist session UUID: `01a107a4-f7d3-7fd1-a77f-f380a0d3db63`. Root UUID: `01a10799-1620-79d0-a738-482cbbbc3cbb`. Cwd: `/Users/cody/.codex/worktrees/769f/railsstarter`. Branch: `codex/81-bootstrap-cdn-sri`. Provider/ref: `github`, `CodySwannGT/railsstarter#81`. Base/future integration target: `main` at `31517fd9aa0c4baf3e5eaecc3d9f7b4c5f271a44`. Starting HEAD: `35acfcfd6ee6cd8ff27b1605a38cf59ed12656d1`.

Complete authored ignored context consumed in nine contiguous, untruncated byte slices: 0–20000, 20000–45000, 45000–70000, 70000–95000, 95000–120000, 120000–145000, 145000–170000, 170000–195000, 195000–221581. File: `.lisa/work-item-context.md`, 221581 bytes, SHA256 `74fb3082cc038bb6b34e66990ad3e42a2506b88273c0ba56b6d82fc7b8858d78`. All authored bodies/comments, provider metadata, post-claim #81 readback, parent/related graph and terminal pagination evidence were consumed. Historical hold text remains history. The operator's direct-session authorization is reported honestly in claim comment 5981821084 without trusted-human impersonation. No resolver bundle is reproduced here.

Read `AGENTS.md`, installed `lisa-wiki-query/SKILL.md`, wiki orientation/index/schema and installed verification/codification/use-product contracts. Official resolver executed with existing Node22.22.0: `/Users/cody/.local/share/mise/installs/node/22.22.0/bin/node /Users/cody/workspace/railsstarter/node_modules/@codyswann/lisa/plugins/lisa-wiki-copilot/scripts/ensure-wiki.mjs --json`. Returned local wiki root in this worktree, no mirror, fresh/offline=false. The wiki index contains orientation/staff and no substantive Bootstrap/runtime synthesis, so current source was inspected. No child AGENTS files were found in source inventory.

Acceptance is exactly: updated CSS/JS load without integrity errors, navbar expands, dismissible flash dismisses, unrelated importmap initializes. No full suite, live AWS, MySQL or broad managed adoption is required by this journey. No access gap discovered. Bare `node` was missing from PATH and explicit existing Node succeeded. Ruby3.4.8 bundle check passed using explicit installed Ruby path.

## Official current supported release selection

Select **Bootstrap 5.3.8**, based on three live official primary-source checks, not on the dated registry observation:

- [Official versions appendix](https://getbootstrap.com/docs/versions/) says v5 is current major and last update is5.3.8, with5.3 Latest documentation.
- [Official5.3 getting-started docs](https://getbootstrap.com/docs/5.3/getting-started/introduction/) currently publish the exact5.3.8 jsDelivr CSS and bundled-JS URLs plus their SHA384 integrity and anonymous crossorigin.
- [Official twbs releases](https://github.com/twbs/bootstrap/releases) labelsv5.3.8 latest. [Immutablev5.3.8 release](https://github.com/twbs/bootstrap/releases/tag/v5.3.8) and official tag distribution provide release identity.

This establishes the maintainers' current supported5.3 documentation line at research time. It is not a promise about future latest versions or every consumer compatibility. The CSS and JavaScript behavior must still be proved empirically in this starter.

## Actual network byte/hash results

Fetched exact CDN bytes using Python urllib with an explicit local Origin, then independently computed SHA384 with Python hashlib and OpenSSL `dgst -sha384 -binary`. All six fetches returned200, without URL redirects. Separate official twbs tag dist fetches matched the selected CDN bytes and hashes exactly. Bytes were processed in memory, no downloaded runtime asset copy is proposed for shipping.

| Resource | Bytes | SHA256 | SHA384 SRI |
| --- | ---: | --- | --- |
| Baseline5.3.3 CSS | 232803 | `3c8f27e6009ccfd710a905e6dcf12d0ee3c6f2ac7da05b0572d3e0d12e736fc8` | `sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH` |
| Baseline5.3.3 bundle JS | 80721 | `0833b2e9c3a26c258476c46266e6877fc75218625162e0460be9a3a098a61c6c` | `sha384-YvpcrYf0tY3lHB60NNkmXc5s9fDVZLESaAA55NDzOxhy9GkcIdslK1eN7N6jIeHz` |
| Selected5.3.8 CSS | 232111 | `d85327d99c7a3ee1f9b5d0500d1370acea3ad2db39c163c2f51f232baedbdede` | `sha384-sRIl4kxILFvY47J16cr9ZwB07vP4J8+LH7qKQnuqkuIAvNWLzeN8tE5YBujZqJLB` |
| Selected5.3.8 bundle JS | 80496 | `e4fd49181388c48ec5040bd3fe66f57c29c8e67fcd8502b3354b96ec7ab47cc7` | `sha384-FKyoEForCGlyvwx9Hj09JcYn3nv7wiPVlz7YYwJrWVcXK/BmnVDxM+D2scQbITxI` |

Selected exact URLs:

- `https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css`
- `https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js`

Independent authority-byte comparisons:

- `https://raw.githubusercontent.com/twbs/bootstrap/v5.3.8/dist/css/bootstrap.min.css`
- `https://raw.githubusercontent.com/twbs/bootstrap/v5.3.8/dist/js/bootstrap.bundle.min.js`

Every CDN response returned `Access-Control-Allow-Origin: *`, `Cross-Origin-Resource-Policy: cross-origin`, `Cache-Control: public, max-age=31536000, s-maxage=31536000, immutable`, `x-jsd-version-type: version` and exact `x-jsd-version`. CSS MIME: `text/css; charset=utf-8`. JS MIME: `application/javascript; charset=utf-8`. These headers support the source's `crossorigin="anonymous"` SRI fetch. Actual browser acceptance is a later independent obligation and is not replaced by these CLI/header checks.

**Baseline defect discovered:** current layout5.3.3 CSS SRI declares `sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YcnS/1WR6zNMYVL+UlKBFaFJiKDs2CO2jRK`, which differs from actual5.3.3 CSS SHA384 above. JS baseline integrity matches. A genuine baseline browser should therefore show the CSS integrity block. This is stronger than assuming baseline only has an old version.

## Exact source surfaces and narrow implementation recommendation

Repository-wide Bootstrap URL search found exactly two asset URLs, both in `app/views/layouts/application.html.erb` at lines17 and28. Current CSS/JS are5.3.3, both declare anonymous crossorigin, JS has defer. Preserve importmap tag placement, local application stylesheet, other links and JS defer. Update those two URLs and their two SRIs together, no dependency-tree/package/Ruby/CI changes.

The real layout has `navbar navbar-expand-lg` but currently has **no toggler or collapse region**. Therefore an expansion click is not presently executable. Smallest coherent source change: add a button with `class="navbar-toggler"`, `data-bs-toggle="collapse"`, `data-bs-target="#navbar-navigation"`, `aria-controls="navbar-navigation"`, `aria-expanded="false"`, `aria-label="Toggle navigation"`, and a `navbar-toggler-icon` span. Add a real `collapse navbar-collapse` container with id `navbar-navigation` containing a Home link to `/`. Keep existing brand and environment label rendering. At a viewport below992px, this makes the exact authored navbar expansion measurable without inventing unrelated business navigation.

`app/views/layouts/_flash_messages.html.erb` renders real alert classes, `fade show`, dismiss button `data-bs-dismiss="alert"` with aria-labelClose and message content. `ApplicationHelper#flash_alert_class` maps notice/success to success. `HomeController#index` has no application data reads and home page currently produces no flash, so inject `flash.now[:notice]` only through an owned test fixture controller/route that renders the real `home/index` and real application layout/partial. Do not ship a permanent runtime demo route or copied fake partial.

Importmap source: `config/importmap.rb` pins application, Turbo, Stimulus, stimulus-loading and all controllers. `app/javascript/application.js` imports Turbo and controllers. Controller bootstrap starts Stimulus and sets `window.Stimulus`. Actual test evidence should prove those real asset requests succeed, `window.Stimulus` exists and Turbo is initialized. A visible source-driven Turbo navigation and/or meaningful Stimulus availability observation can supplement requests. Do not add an unrelated controller merely to satisfy a fixture assertion.

## Minimal source-coupled runtime and controls

Existing `spec/fixtures/runtime/smoke.rb` and `spec/fixtures/runtime/acceptance.json` are already shipped source-coupled AWS-SDK fixture consumers. Standalone runtime harness avoids `rails_helper`, whose schema-maintenance route remains unsafe on ambient databases. Test environment disables caching, enables file server, uses null cache and test mail delivery. Home/health endpoints do not require persistent data.

Recommended owned browser server boot: load existing runtime harness, call `DependencySmoke.validate_environment!`, `DependencySmoke.configure_environment`, `DependencySmoke.configure_aws`, require actual `config/environment`, call `DependencySmoke.validate_authored_responses!`. Keep `RUNTIME_SMOKE_DB=0`, `RUNTIME_SMOKE_IMAGE=0`, RAILS_ENV/RACK_ENV=test. The existing harness validates unique safe local database namespace/host/port even in database-free boot, but does not open connections in that mode. Use its allowed namespace (e.g. `railsstarter_63_smoke_bootstrap81`) for reuse, or author a comparably guarded owned fixture if requiring81-specific namespace. No schema helper or database preparation should run. No MySQL is needed unless new evidence shows actual data journey requirements.

Its configure_aws globally enables `stub_responses: true`, supplies authored SSM/CloudFormation/SecretsManager responses and requires consumed `_RUNTIME_SMOKE_FIXTURE=authored-local-only`. This is appropriate local evidence and must be retained. Do not bypass AWS loading with a dummy secret and call that fixture consumption. Clear ambient AWS/OTEL/database URLs narrowly inside the subprocess, as the harness does. Disable Solid Queue in Puma and keep owned pid/port/cwd identity, stop only positively proved owned server/process.

Owned fixture controller example design: subclass actualHomeController, set `flash.now[:notice]` then `render "home/index"`. Add the fixture route after boot in the owned server process, e.g. `/__bootstrap_acceptance`, so the route never ships to application source. The cold `/` page verifies ordinary starter source and fixture route supplies the flash precondition using the same source layout, helper and partial.

Negative control should use an owned temporary **copy of actual application layout source** with exactly one SRI hash altered and all other real source views/modules/assets retained. Select that owned layout through fixture rendering or owned view-path precedence. Use separate CSS and JS controls if feasible. Record resource error/console integrity block at each real boundary, style disappearance for CSS and absent Bootstrap behavior for JS, while importmap remains independently available. Restore/discard owned negative layout and rerun success against final source. No mutation to a shared browser tab or sibling source and no replacement CDN imitation page.

Interactive evidence must be produced by a real capable available browser controller, with actual clicks, network/SRI/console observations and style/JS effects. Test-run output alone is not interactive evidence. Independent verifier should compare the final source file hashes, selected network asset byte/hash identity, exact browser resource URLs/SRIs/crossorigin and successful/blocked resource outcomes. Success must not pass by fixture-supplied fake styles or Bootstrap objects.

## Codification contract and existing runner

Installed `lisa-codify-verification/SKILL.md` mandates observable source-coupled regression, actual PASS and actual deliberately-broken FAIL, same journey inputs, and BDD scenario/platform coverage. It forbids treating captured manual artifacts as tests. The explicit operator stop overrides skill commit/push steps at this local stage.

No Playwright/Cypress/e2e config or BDD contract currently exists in this checkout. The project already declares Capybara and Selenium in its installed test bundle and RSpec in Lisa tooling, so use that existing stack rather than install a new framework/dependency tree. A bounded `spec/browser/*_spec.rb` can require `spec_helper` only, start the guarded real Rails fixture server and use an owned Selenium/Capybara Chrome session to exercise actual source. Existing source dirs are `spec/runtime`, `spec/deployment` and post-integration `spec/workflows`. Wire discovery into default RSpec spec tree, not a detached parallel test tree. Avoid unsafe `rails_helper` and transactions. The browser regression must test real loaded stylesheet/computed styles, Bootstrap collapse/alert effects and real importmap initialization, not only source text/mirror URLs.

The exact BDD bootstrap/gate route should be read from installed `bdd-e2e-coverage` rule before encoding. Limit it to81's web-only behavior. No mobile/native obligation is implied by this ticket. Any genuinely unavailable runtime browser/driver or gate is a scoped integration gap, not evidence of pass. Root should choose source-coupled meaningful controls and report local-only codification status before shipping.

## #65 ancestry and integration

`git merge-base HEAD 2b7af506` returned current HEAD `35acfcfd6ee6cd8ff27b1605a38cf59ed12656d1`; `git merge-base --is-ancestor HEAD 2b7af506` succeeded. Exactly one new commit lies ahead: `2b7af50617a8e3758ac1523e7e29b8d369db347d` with Work-Item65 and original Codex coauthor trailers. It preserves61/63 ancestry and contains the reviewed CI caller retirement/opt-in deployment and regression evidence. It does not provide fresh hosted AMD64/PR delivery proof or broad managed adoption.

Normal merge/fast-forward is relevant to preserving reviewed proof and preventing61 deployment caller reactivation while81 tests source. Root reported completing the normal fast-forward and re-reading81 binding without replacing it. No dirty root upgrade was copied. Existing65/61/63 source and trailers remain ancestry, not81-owned edits.81 final diff should be measured against integrated2b7af506 as well as the starting HEAD so the owned change filelist is distinct from ancestry.

## Usage snapshot and limits

Native cumulative snapshot, stable entry identity `lisa-implement:81:01a107a4-f7d3-7fd1-a77f-f380a0d3db63`, observed2026-10-04T16:05:13.318Z: input1925520, cached_input1804416, cache_write0, output3802, reasoning_output340, total1929322. Source is the actual native session token_count total_token_usage. Model/cost unavailable in that snapshot. Replace this same entry with later cumulative snapshot, never sum it with prior snapshots from this same session. Session source pointer: `/Users/cody/.codex/sessions/2026/10/04/rollout-2026-10-04T12-00-14-01a107a4-f7d3-7fd1-a77f-f380a0d3db63.jsonl`.

Research does not claim browser PASS, codification PASS, independent verifier approval, commit, PR, merge or hosted CI. No owned server/container/volume was started by research, so no process cleanup was needed. Only this sanitized report was written. Baseline runtime/browser and implementation remain with the bounded builder and independent verifier.
