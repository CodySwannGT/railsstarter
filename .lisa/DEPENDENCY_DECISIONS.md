# Dependency Decisions

<!-- lisa-dependency-decisions:v1 -->

This file is the project's record of **why we keep each material dependency**.

A *material* dependency is one whose failure, disappearance, or bad update would
break something a user can see, or would cost real time to replace. Not every
package in the lockfile belongs here — only the ones that own a capability.

You do not need to be an engineer to read this file. Every entry starts with a
plain-language explanation of what the dependency does for us, and every entry
names what evidence would catch a bad update. If an entry does not answer those
two questions in words a non-engineer understands, the entry is wrong — fix the
words, not the reader.

Lisa seeds this file once and never overwrites it. It is yours to maintain.

## How to use this file

1. Copy the **Entry template** below for each material dependency.
2. Add the filled-in entry to the end of the **Records** section.
3. Fill in every field. If you do not know the answer yet, write
   `_Not yet decided_` — never leave a field blank and never guess. An
   unanswered field is an honest question for the next review; a guess is a
   wrong answer that nobody will re-check.
4. Re-read an entry whenever that dependency is upgraded across a major version,
   changes maintainers, or its detection evidence fails.
5. Update `Last reviewed` every time someone actually re-reads the entry, even
   if nothing else changed.

### Entry format (stable, appendable)

Entries are deliberately uniform so they can be added by hand or appended by a
script without rewriting the rest of the file:

- Every entry is a level-3 heading (`### <name>`) followed by the nine field
  bullets, always in the order shown in the **Entry template**.
- Entries live under `## Records`, which is the last section of this file, and
  new entries are appended to the end. A `###` heading inside `## Records` is
  always an entry and never guidance — that is what makes the section safe to
  parse and append to.
- Nothing after `## Records` is guidance, so appending to the end of the file is
  always safe.
- `_Not yet decided_` is the reserved marker for an unanswered field, so
  unfilled entries are visibly honest rather than silently empty.

## The rest of the dependency-ownership layer

This file is one of five parts, and it is the only one that lives in your
project's own source. Three of the other four are still readable from here,
because they ship inside the installed Lisa package — paths starting
`node_modules/` below. The remaining two exist only in the Lisa project itself
and are called out as such; do not go looking for them in this repository.

**Installed in this project** (readable from your project root):

- **The six trust classes** — how much scrutiny a dependency deserves, set by
  what it can reach rather than by how famous it is. The six are: mature
  ecosystem primitive, fast-moving standard implementation, build/development
  tool, runtime-critical service client, thin wrapper suitable for in-house
  ownership, and temporary/experimental dependency. Sign-off rules differ by
  class and by moment: a **runtime-critical service client** needs a human
  sign-off to be added and at every major upgrade; a **temporary/experimental
  dependency** needs none to be added — moving fast is the point — but must
  carry a written expiry date no more than one quarter out and a named exit, and
  then needs sign-off to extend past that date or to promote it. The full
  definitions, with the evidence each class demands, are at
  `node_modules/@codyswann/lisa/plugins/lisa/rules/reference/dependency-trust-classes.md`.
  Your coding agent already has these loaded, so "which trust class is this, and
  what evidence does that class require?" is a question you can just ask it.

- **The confidence-rebuild kit** — the seven things a change must prove when a
  dependency is removed and the capability rebuilt in-house: real corpus,
  conformance fixtures, negative fixtures, coverage as a gap detector,
  provenance and license review, migration and update plan, and rollback or
  replacement criteria. All seven are required; a partial kit is the finding. It
  does **not** apply to an ordinary version bump. Full text at
  `node_modules/@codyswann/lisa/plugins/lisa/rules/reference/dependency-internalization-kit.md`.

- **The manifest-authoritative duplicate-pin policy** — a version belongs in
  `package.json` and nowhere else; every copy of the literal in a workflow or a
  script is a second edit site a routine bump can miss. Lisa ships a detector
  you can run against this project:

  ```bash
  node node_modules/@codyswann/lisa/scripts/check-duplicate-versions.mjs --root . --scan .
  ```

  Be honest about what it is today: **advisory**. It is not wired into this
  project's `package.json` scripts and it does not fail a build, so nothing runs
  it unless you do. It also deliberately under-reports rather than over-reports,
  so a clean run is not proof that no pin was duplicated.

**Not shipped here — they exist only in the Lisa project.** Neither path below
resolves from this repository; you would have to open Lisa's own repository to
read them, and you do not need either one to use this file.

- **A worked, filled-in example** — Lisa keeps this same file for its own
  dependencies, written from repository evidence only, with every unanswered
  field tracked as a ticket rather than guessed. In the Lisa project it is at
  `.lisa/DEPENDENCY_DECISIONS.md`.

- **The full operator walkthrough** — a plain-language guide to deciding whether
  a proposed dependency change is acceptable, with a checklist for each of the
  three shapes (adding a dependency, taking one in-house, an ordinary version
  bump). In the Lisa project it is at
  `wiki/playbooks/dependency-ownership-operator-guide.md`.

Nothing above is enforced by a build gate. Nothing blocks a change that skips
this file, names no trust class, or removes a dependency with no rebuild
evidence. That is deliberate — these are review disciplines, not lint rules —
and it is exactly why the escalations below matter.

## When to escalate

Reading an entry should end in a decision. Raise these to an owner rather than
letting them sit — each one means the project is carrying a risk nobody has
accepted on purpose:

- **Nothing would catch a bad update.** The detection-evidence field says
  "nothing would catch it". We are trusting the dependency blind.
- **The review is older than the dependency.** `Last reviewed` predates the last
  major upgrade of that dependency, so the record describes software we are no
  longer running.
- **Nobody is behind it.** The trust basis names no maintainer, no owner, or no
  release history — on our side or theirs.

An entry full of `_Not yet decided_` is not itself an escalation; it is a
to-do. The three items above are escalations because someone already looked and
the answer was bad.

## What each field means

- **Why we keep it** — the plain-language reason, written for a non-technical
  reader. Lead with the outcome it protects, not the mechanism.
- **What it is (dependency)** — the package or service name, and the version
  range in use.
- **What it does for us (owned capability)** — the single capability this
  dependency is responsible for. If you cannot name one capability, the
  dependency is either not material or is doing too much.
- **Why we believe it's safe (trust basis)** — why we believe this dependency
  will still be maintained and safe next quarter. Evidence, not vibes: who
  maintains it, release cadence, security-response history, how widely it is
  used, whether it is pinned.
- **What breaks if this is compromised (exposure)** — what it can reach and what
  breaks if it misbehaves. Does it run at build time only, or in production?
  Does it touch user data, secrets, the network, or CI credentials?
- **What it would take to replace (replacement cost)** — what it would actually
  take to remove or swap it: rough effort, what would have to be rewritten, and
  whether a viable alternative exists today.
- **What would catch a bad update (detection evidence)** — the specific check
  that would **fail** if an update broke the owned capability. Name the test,
  suite, workflow, or monitor. If the honest answer is "nothing would catch it",
  write that down — it is the most valuable line in the entry. Use
  `_Not yet decided_` only when nobody has looked yet, which is a different
  statement from "we looked, and nothing covers this".
- **Who owns this and how often we recheck (owner / review cadence)** — who is
  accountable for this entry and how often it gets re-read.
- **Last reviewed** — ISO date (`YYYY-MM-DD`) of the most recent review.

## Entry template

Copy this block, fill it in, and append it to the end of **Records** below. Keep
the nine bullets in this order. Any field you cannot answer yet gets
`_Not yet decided_`.

### <dependency name>

- **Why we keep it:** <plain-language reason a non-technical reader can follow>
- **What it is (dependency):** <package or service name> `<version range>`
- **What it does for us (owned capability):** <the one capability it owns>
- **Why we believe it's safe (trust basis):** <maintainer, cadence, adoption,
  security history, pinning>
- **What breaks if this is compromised (exposure):** <build-time vs runtime;
  data, secrets, network, CI reach>
- **What it would take to replace (replacement cost):** <effort to remove or
  swap, and the alternative>
- **What would catch a bad update (detection evidence):** <the named check that
  fails if an update breaks it>
- **Who owns this and how often we recheck (owner / review cadence):**
  <accountable owner> / <cadence>
- **Last reviewed:** <YYYY-MM-DD>

## Records

> **The two entries below are EXAMPLES.** They are here so you can see the shape
> of a good record — the first complete, the second still being filled in.
> Replace them with your own material dependencies, or delete them once you have
> written real entries.

### ESLint (EXAMPLE — a complete entry)

- **Why we keep it:** It is the automatic reviewer that reads every change
  before a human does and refuses the ones that break our agreed coding rules.
  Without it, those rules become suggestions and the codebase drifts a little
  with every change until nobody can predict how anything is written.
- **What it is (dependency):** `eslint` `^9`
- **What it does for us (owned capability):** Automated enforcement of
  code-quality and style rules on every commit and every pull request.
- **Why we believe it's safe (trust basis):** Maintained by the OpenJS
  Foundation with a published release cadence and a documented
  security-disclosure process; used by a very large share of the JavaScript
  ecosystem, so breakage is found by other people before it reaches us. The
  major version is pinned, so an upgrade is a deliberate decision rather than
  something that arrives on its own.
- **What breaks if this is compromised (exposure):** Build-time and CI only. It
  never runs in production and never touches customer data. It does run inside
  CI, so a compromised release could in principle read CI environment variables
  — which is why the version is pinned and upgrades are reviewed.
- **What it would take to replace (replacement cost):** High. Every rule
  configuration and every custom rule would have to be re-expressed in another
  linter, and the pre-commit and CI wiring rebuilt. Alternatives exist (for
  example Biome or oxlint) but none is a drop-in match for the current rule set
  today.
- **What would catch a bad update (detection evidence):** The `lint` check in
  CI. Warning sign: if lint passes a change we know breaks a rule, the checking
  has silently stopped working — the rule tests exist to catch exactly that.
- **Who owns this and how often we recheck (owner / review cadence):** Platform
  / engineering owner — reviewed each major version upgrade, and at least once
  every 6 months.
- **Last reviewed:** _Not yet decided_ (example entry — never reviewed)

### sharp (EXAMPLE — an entry still being filled in)

- **Why we keep it:** It resizes and re-encodes every image users upload, so
  photos load quickly instead of being served at full camera resolution.
- **What it is (dependency):** `sharp` `^0.33`
- **What it does for us (owned capability):** Server-side image resizing and
  format conversion on upload.
- **Why we believe it's safe (trust basis):** _Not yet decided_ — nobody has
  checked who maintains it or how quickly security issues get fixed.
- **What breaks if this is compromised (exposure):** Runs in production and
  processes files uploaded by users. It ships native code, so its reach is
  wider than a pure-JavaScript package.
- **What it would take to replace (replacement cost):** _Not yet decided_
- **What would catch a bad update (detection evidence):** _Not yet decided_ —
  this is the gap to close first, because nothing currently proves an upgrade
  did not silently corrupt uploaded images.
- **Who owns this and how often we recheck (owner / review cadence):**
  _Not yet decided_
- **Last reviewed:** _Not yet decided_

### Lisa

- **Why we keep it:** Keep the starter’s checks, task tracking and generated developer tooling current.
- **What it is (dependency):** `@codyswann/lisa ^4.70.1`
- **What it does for us (owned capability):** Managed engineering tooling.
- **Why we believe it's safe (trust basis):** Class 4 — Runtime-critical service client. Lisa supplies credential-resolving and provider-writing integrations, and its CI tooling receives provider permissions, so development-only installation does not establish the smaller class-3 exposure. Genuine published4.70.1 archive integrity/gitHead and exact installed templates verified. Published npm engine policy still says please-use-bun; two high development advisories remain unresolved. This classification records the exposure; replacement cost, final integration evidence and hosted monitoring still need completion before class-specific governance is qualified. Existing session authorization covers this upgrade; no new approval is inferred.
- **What breaks if this is compromised (exposure):** Development tools and CI can read source, local files and available process credentials.
- **What it would take to replace (replacement cost):** _Not yet decided_
- **What would catch a bad update (detection evidence):** Explicit full apply/reapply, native hooks, raw npm audits and history-scanner checks. Hosted delivery and the final assembled push remain pending.
- **Who owns this and how often we recheck (owner / review cadence):** Cody owns current issue85; future cadence _Not yet decided_.
- **Last reviewed:** 2026-10-05

### Brakeman

- **Why we keep it:** Detect unsafe Rails code before shipping.
- **What it is (dependency):** `brakeman ~> 8.1 (installed8.1.0)`
- **What it does for us (owned capability):** Rails static security scanning.
- **Why we believe it's safe (trust basis):** Class 3 — Build/development tool. Gemfile.lisa limits installation to development/test; current use scans starter source. Existing starter dependency, resolved through ordinary Bundler from its published release; the actual current scan exits0. Reclassify if use gains production data or credential reach.
- **What breaks if this is compromised (exposure):** Scans source during development and CI.
- **What it would take to replace (replacement cost):** _Not yet decided_
- **What would catch a bad update (detection evidence):** Actual Brakeman8.1.0 scan on the current source and original pre-push hook.
- **Who owns this and how often we recheck (owner / review cadence):** Cody owns current issue85; future cadence _Not yet decided_.
- **Last reviewed:** 2026-10-05

### Database consistency

- **Why we keep it:** Find disagreements between model behavior and the database schema.
- **What it is (dependency):** `database_consistency ~> 3.0 (installed3.0.14)`
- **What it does for us (owned capability):** Model/schema consistency analysis.
- **Why we believe it's safe (trust basis):** Class 3 — Build/development tool. Gemfile.lisa limits installation to development/test; current qualification reads a positively owned test database. Existing tool, ordinary published Bundler resolution. The real CLI ran against positively owned current MySQL; exit1 reports four counter-model warnings rather than an API failure. Reclassify before use against production data or credentials.
- **What breaks if this is compromised (exposure):** Reads application models and database metadata in the selected environment.
- **What it would take to replace (replacement cost):** _Not yet decided_
- **What would catch a bad update (detection evidence):** The real database_consistency CLI. Current warnings: counter_key uniqueness/presence/length and expires_at presence; application-policy disposition remains not yet decided.
- **Who owns this and how often we recheck (owner / review cadence):** Cody owns current issue85; future cadence _Not yet decided_.
- **Last reviewed:** 2026-10-05

### Rack mini profiler

- **Why we keep it:** Explain slow development requests.
- **What it is (dependency):** `rack-mini-profiler ~> 5.0 (installed5.0.0)`
- **What it does for us (owned capability):** Development request profiling.
- **Why we believe it's safe (trust basis):** Class 3 — Build/development tool. Gemfile.lisa limits this profiler to development; the qualification request is synthetic. Existing development-only dependency, ordinary published Bundler resolution. A real Rack request retained status/body and produced its profile ID header. Reclassify if profiling gains production data or credential reach.
- **What breaks if this is compromised (exposure):** Executes in development and can observe request data.
- **What it would take to replace (replacement cost):** _Not yet decided_
- **What would catch a bad update (detection evidence):** Actual Rack middleware probe. SQL profiling integration has not been independently qualified.
- **Who owns this and how often we recheck (owner / review cadence):** Cody owns current issue85; future cadence _Not yet decided_.
- **Last reviewed:** 2026-10-05

### RSpec Rails

- **Why we keep it:** Catch application regressions before shipping.
- **What it is (dependency):** `rspec-rails ~> 8.0 (installed8.0.4)`
- **What it does for us (owned capability):** Rails test integration.
- **Why we believe it's safe (trust basis):** Class 3 — Build/development tool. Gemfile.lisa limits installation to development/test; qualified application and service fixtures are synthetic. Existing test tool, ordinary published Bundler resolution. The actual429-example suite reaches application behavior and keeps zero-example failure enabled. Reclassify if tests gain production data or credential reach.
- **What breaks if this is compromised (exposure):** Executes application and fixture code during tests.
- **What it would take to replace (replacement cost):** _Not yet decided_
- **What would catch a bad update (detection evidence):** The full meaningful RSpec suite, owned runtime fixtures and original pre-push hook. Latest full run remains exit1 due to Chrome session startup; isolated browser3/0 is not an aggregate pass.
- **Who owns this and how often we recheck (owner / review cadence):** Cody owns current issue85; future cadence _Not yet decided_.
- **Last reviewed:** 2026-10-05

### RuboCop Capybara

- **Why we keep it:** Review browser-test code consistently.
- **What it is (dependency):** `rubocop-capybara ~> 3.0 (installed3.0.0)`
- **What it does for us (owned capability):** Capybara-specific lint rules.
- **Why we believe it's safe (trust basis):** Class 3 — Build/development tool. Gemfile.lisa limits installation to development/test; current use lints test source. Existing tool, ordinary published Bundler resolution. Current plugin loads with the full126-file Ruby lint run, exit0. Reclassify if use gains production data or credential reach.
- **What breaks if this is compromised (exposure):** Reads development/test source.
- **What it would take to replace (replacement cost):** _Not yet decided_
- **What would catch a bad update (detection evidence):** Actual current RuboCop run and native staged-file hooks. No independent mutation proof of every plugin rule.
- **Who owns this and how often we recheck (owner / review cadence):** Cody owns current issue85; future cadence _Not yet decided_.
- **Last reviewed:** 2026-10-05

### RuboCop YARD

- **Why we keep it:** Keep code documentation consistent.
- **What it is (dependency):** `rubocop-yard ~> 1.3 (installed1.3.0)`
- **What it does for us (owned capability):** YARD-specific lint rules.
- **Why we believe it's safe (trust basis):** Class 3 — Build/development tool. Gemfile.lisa limits installation to development/test; current use lints source documentation. Existing tool, ordinary published Bundler resolution. Genuine managed plugin configuration loads in the full126-file Ruby lint run, exit0. Reclassify if use gains production data or credential reach.
- **What breaks if this is compromised (exposure):** Reads source during development and CI.
- **What it would take to replace (replacement cost):** _Not yet decided_
- **What would catch a bad update (detection evidence):** Actual RuboCop run and staged-file hooks. No independent mutation proof of every plugin rule.
- **Who owns this and how often we recheck (owner / review cadence):** Cody owns current issue85; future cadence _Not yet decided_.
- **Last reviewed:** 2026-10-05

### Shoulda matchers

- **Why we keep it:** Make model behavior easier to test.
- **What it is (dependency):** `shoulda-matchers ~> 8.0, >= 8.0.1 (installed8.0.1)`
- **What it does for us (owned capability):** Reusable Rails/model assertions.
- **Why we believe it's safe (trust basis):** Class 3 — Build/development tool. Gemfile.lisa limits installation to development/test; the qualified model fixture is synthetic. Existing test tool, ordinary published Bundler resolution. Its real presence matcher succeeds against an authored ActiveModel validation. Reclassify if tests gain production data or credential reach.
- **What breaks if this is compromised (exposure):** Executes model assertions in tests.
- **What it would take to replace (replacement cost):** _Not yet decided_
- **What would catch a bad update (detection evidence):** Real public presence-matcher probe and the application suite; the probe alone is not full SQL integration proof.
- **Who owns this and how often we recheck (owner / review cadence):** Cody owns current issue85; future cadence _Not yet decided_.
- **Last reviewed:** 2026-10-05

### SimpleCov

- **Why we keep it:** Expose untested application paths.
- **What it is (dependency):** `simplecov ~> 1.3, >= 1.3.2 (installed1.3.2)`
- **What it does for us (owned capability):** Line and branch coverage measurement.
- **Why we believe it's safe (trust basis):** Class 3 — Build/development tool. Gemfile.lisa limits installation to development/test; it instruments the synthetic test suite. Existing tool, ordinary published Bundler resolution. Legacy configuration genuinely failed; supported current API keeps80% line/70% branch floors and produces HTML/JSON. Reclassify if use gains production data or credential reach.
- **What breaks if this is compromised (exposure):** Instruments Ruby only in tests.
- **What it would take to replace (replacement cost):** _Not yet decided_
- **What would catch a bad update (detection evidence):** Actual legacy RED/current API GREEN and full-suite96.04% line/92.16% branch. Browser-only rerun retains coverage exit2; no thresholds or filters were weakened.
- **Who owns this and how often we recheck (owner / review cadence):** Cody owns current issue85; future cadence _Not yet decided_.
- **Last reviewed:** 2026-10-05
