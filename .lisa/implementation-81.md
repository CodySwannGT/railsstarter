# Bootstrap CDN/SRI implementation — local stage

Delivery remains in progress. Stop before commit, push or PR. Root reviews first. Keep #81 open/in-progress with binding and private context retained.

## Inputs and scope

Consumed the current complete ignored context, 221581 bytes, SHA256 `74fb3082cc038bb6b34e66990ad3e42a2506b88273c0ba56b6d82fc7b8858d78`, plus current plan, updated actual roster and research report. This native teammate first completed only bounded input resolution, then received the separately scoped build/runtime assignment after the roster. Independent researcher and browser verifier remain actual separate teammates.

Authored criteria govern: CSS/JS load with correct SRI, navbar expansion and flash dismissal work, unrelated importmap modules initialize. Historical audit hold and original comments remain preserved. Current direct-session operator authorization is reported as automation provenance, not trusted-human tracker release evidence. Parent/upstream scope and #65 original ancestry/provenance remain intact.

## Application source

Only `app/views/layouts/application.html.erb` changed. Updated both CDN URLs to the researched current supported Bootstrap5.3.8 and both SHA384 values to the independently verified official bytes. Anonymous crossorigin, JS defer, importmap placement and local stylesheet remain intact. Added the minimum accessible navbar toggler and collapse region with an existing-root Home destination, making authored expansion executable. No other app reference, flash partial, module, dependency, Ruby, CI or guard changed.

Final layout bytes2558, SHA256 `7b7839ba36a3c46f5401965561db1760ff9c287ed562aca0d12121843506920d`. Scoped diff measured against integrated #65 head `2b7af50617a8e3758ac1523e7e29b8d369db347d`; no new commit. Existing #61/#63/#65 ancestry is preserved, not copied from dirty root source.

Unchanged relevant source hashes:

| File | SHA256 |
| --- | --- |
| `app/views/layouts/_flash_messages.html.erb` | `87b08a6f316aeae3cae6ef77731092e91d61f004d77f7791f08c8e2262077eb7` |
| `app/javascript/application.js` | `d3f3d1b31962c4112a529e1f9af3760286edaf0969a4367c7ed90a4c96647650` |
| `app/javascript/controllers/application.js` | `b5836315bab7b8d055ac3346bf57f933fa8aa8b37e9ea7b704cb2ae2bff129b8` |
| `config/importmap.rb` | `6a9eb320b24efad132cea99ad8a7cf11940f99625695cf0f152583c2b8e9ba34` |

## Owned actual Rails runtime

Database-free real Rails/Puma server at `http://127.0.0.1:63736`, fixture route `/__bootstrap_acceptance`. Fixture controller subclasses actual HomeController, injects `flash.now[:notice]` and renders actual `home/index`, application layout and real flash partial. No fixture route or demonstration page was added to application source.

Owned scratch: `/var/folders/_2/29n6gy1s42777swvq24j3fh00000gn/T/railsstarter-81-01a10799-1wuhlk7v`. `owner.json`/`server-owner.json` bind root and builder UUID, exact cwd, PID, port and consumed fixture evidence. Server launcher is `server.rb` in that directory. Initial PID78516 was positively checked by exact launcher command and127.0.0.1:63736 listener before SIGTERM; exec61247 exited0. After independent baseline capture, normal template-cache refresh started the updated runtime as PID78840, exec13046, same owned port and path. This is source reload, not a team/session restart.

Start command selects existing Ruby3.4.8 PATH, `bundle exec ruby <owned scratch>/server.rb`, with explicit actual root/scratch/port and RAILS_ENV/RACK_ENV=test. Existing authored `DependencySmoke` environment guard and SDK fixture configuration boot the actual app. Namespace `railsstarter_63_smoke_81_01a10799`, local dummy database port19481, `RUNTIME_SMOKE_DB=0` and `RUNTIME_SMOKE_IMAGE=0`. The permitted namespace follows the inherited fixture contract. No MySQL was started and no schema/helper/migration operation ran. `Mysql2::Client.new` is denied before any connection in this owned runtime. Ambient AWS/OTEL settings are cleared narrowly by the inherited fixture; global AWS stub responses are enabled. Boot positively consumed `_RUNTIME_SMOKE_FIXTURE=authored-local-only`; no live AWS calls or writes.

Actual source response returned HTTP200 with correct current URLs/SRI and real flash. Normal `/` and `/up` remain available. Baseline independent verifier observed previous5.3.3 CSS network200 but sheet unavailable and explicit integrity block, absent navbar toggler, JS available and real Stimulus/Turbo initialized. Evidence is under `evidence/81/`.

## Owned browser negative-control copies

After baseline, generated complete copies of final actual layout into owned scratch `views/layouts/control_css.html.erb` and `control_js.html.erb`. Each is2558 bytes and differs from final source by exactly one character in that resource's declared SRI; CDN URLs, other resource SRI and all app views/modules remain unchanged. Runtime fixture selects these layouts only for `?control=css` / `?control=js`. Normal fixture and ordinary root still render source. No imitation asset is shipped.

`control-manifest.json` records source digest, changed-character count and control digests: CSS `fb58197466dc9b02c21cde218eb271f4ed39e08337760607d8879a535720bdea`, JS `f02284726595b3b1e92dce0fb81d17adadcba2e34ee8da4c8fa41dc16fb19684`. Independent verifier owns interactive success, corrupted-boundary behavior and restoration proof. Source hashes/HTTP readbacks are not browser proof.

## Scoped checks and remaining stage

`git diff --check` passed. ERB compiled successfully in a Ruby method context, matching layout yield usage. An initial top-level ERB compiler probe rejected valid `yield` syntax because the probe omitted a method context; corrected probe passed and actual Rails renders200. No unnecessary full suite ran.

Independent actual interactive PASS, CSS/JS single-character negative controls and restored PASS are complete, owned and reported by the separate browser verifier in `.lisa/verification-81.md`. Actual browser response bytes/hashes in `evidence/81/success-network.json` match independent research and final source declarations. The chosen CSS/JS both returned200, CORS wildcard is compatible with anonymous crossorigin, and browser SRI allowed them. Observable styles, real navbar expansion, flash dismissal, Turbo Home navigation and Stimulus initialized. Negative CSS was blocked with sheet absent; negative JS was blocked with Bootstrap absent and interactions inert. Source hashes/CLI readback do not substitute for those observations.

After actual independent PASS, applied current Lisa codify-verification and BDD contracts using existing RSpec/Capybara/Selenium and actual installed Chrome, without framework/dependency/CI adoption. `spec/browser/bootstrap_assets_spec.rb` and its two narrow fixtures boot the actual application, render actual views/modules, consume existing authored SDK fixtures and deny database connections. No copied or intercepted CDN asset is shipped. Each example owns its browser and Ruby server, unique scratch/port/token; ensure cleanup positively identifies the child and token before stopping/removing.

Final codification source identities are in `evidence/81/codification-source-manifest.json`:

| File | Bytes | SHA256 |
| --- | --- | --- |
| `spec/browser/bootstrap_assets_spec.rb` |4180|`e64d1acb9bfb8d18aef9506eb0be2df60d1ebce238d5102752b8f5de351f1d32`|
| `spec/fixtures/browser/bootstrap_server.rb` |2842|`bed7cea4343144a9bf1a9d07161f5f54325b230243142d0fbf71d9a8b17bd446`|
| `spec/fixtures/browser/bootstrap_harness.rb` |4902|`cad89380186df863c1fac5a962babab42feaf1b191f9bb53d8ab61d6fbb8460d`|

Exact named run argv, executed identities and exit codes are in `evidence/81/codification-runs.json`; corresponding `.json` reporters and `.log` boundary outputs are retained. Final restored GREEN ran only these three examples:3 passed/0 failures. CSS and JS success-test falsification each ran one example and failed on the actual stylesheet/JavaScript blocked-resource assertion before metadata comparisons. Two negative-checker falsification examples visited normal source instead of corrupt copies and both failed on actual stylesheet-present/Bootstrap-object properties. Only the two owned spec visit inputs were temporarily changed, with concurrent-change-checked try/finally restoration. Actual counterfactual spec SHA256 `b560a4bcb854e23858f24e0ea0ccf096cbb8df1077a6206987b2d1433497e9c8`; original/restored hash is the final spec above. Final GREEN follows restoration. Earlier drafts are not the final falsification evidence.

Ordinary native RSpec discovery (`--dry-run`) finds64 examples versus61 when excluding only the new browser spec: exactly the three named browser examples are included by default. This does not execute or claim a full-suite PASS. Scoped RuboCop checks only the three new Ruby files:3 files/0 offenses. Logs and discovery adapters are under `evidence/81/`. Child-process application code is not represented by parent SimpleCov; no application-coverage claim is made.

Narrow BDD feature/map describes the three real obligations with stable IDs BDD-BOOTSTRAP-001/002/003, ratified issue81 provenance, web-only runner, no waivers/exclusions. The scoped web floor100 matches current3/3 mapping. Existing absolute shipped Node22 gate and matrix entrypoints ran with `BDD_BASE_SHA=2b7af50617a8e3758ac1523e7e29b8d369db347d`; exact argv/results and actual named execution adapter are in `evidence/81/bdd-commands.json`, `bdd-execution.json` and `bdd-gate.json`. Gate completed with0 findings,3 discovered/mapped/executed/passed and100% traceability. Generated `bdd/coverage-report.json`, `docs/e2e-bdd-coverage.md` and `docs/bdd-scenario-matrix.md` report traceability separately from supplied actual execution.

Owned runtime cleanup is complete. Before stopping PID78840, exact root/builder UUID, cwd, owned scratch, command and127.0.0.1:63736 listener were positively checked. SIGTERM produced exec13046 exit0; PID/listener absent and exact owned scratch removed. Sanitized readback and retained control identities: `evidence/81/runtime-cleanup.json`. Seven final codified-example cleanup records in `evidence/81/test-cleanup.jsonl` each prove owned child reaped, token verified and scratch removed; each owned Selenium session quit. No MySQL/container/volume was created. Siblings/shared scratch/browser sessions are preserved.

Source deliverables owned by this builder: application layout; three Ruby spec/fixture files; `bdd/features/bootstrap-assets.feature`; `bdd/coverage-map.json`; generated `bdd/coverage-report.json`; two generated docs above. Durable implementation/evidence reports are separate local handoff artifacts.

Delivery remains in progress. External immutable CDN availability remains a test runtime prerequisite; this source-bound proof does not claim offline determinism. No hosted CI execution or new package/CI/guard wiring was added because those changes are outside this authored lane and operator scope. Existing native RSpec default discovery is proved; CI Browser/Chrome provisioning and BDD-script wiring remain gaps for subsequent authorized delivery. Commit/push/PR/merge/deploy remain unperformed at the explicit local stop. Issue81, binding and private context remain retained.

MLD: mistake — initial top-level ERB probe rejected valid layout yields; corrected to method context. An early Capybara shared-session setup needed existing thread-safe mode and final per-example owned sessions. The shipped BDD discovery validator requires dot suffix `.rb`, corrected from `_spec.rb`. Scoped lint drove final fixture extraction without disabling cops. Learning — actual stylesheet/script behavior must precede metadata assertions for meaningful falsification; negative-checker input mutations need their executed identity recorded separately from restored source. Test-mode cached templates require owned runtime source refresh. Desire — none.


Exact nine-file final source manifest/diff: `evidence/81/builder-final-source-manifest.json` and `builder-final-source-diff.patch`. No code changed after final restored GREEN/lint/gate. Final `git diff --check` passed. Native cumulative usage pointer: `evidence/81/builder-native-usage.json`, session UUID `01a1079a-1893-7142-94c8-1c560545d8d1`, stable usage ID `lisa-implement:81:01a1079a-1893-7142-94c8-1c560545d8d1`. This is the same session as input resolution; replace earlier cumulative snapshots, never sum or charge assignment roles separately. Parent will refresh its authoritative final all-session snapshot at handoff.
