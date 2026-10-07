# Scoped plan — Bootstrap CDN/SRI #81 local handoff

## 2026-10-07 design-source review correction

Current operator authorization includes completing and merging the batch. The enabled official design-source gate rejected the changed layout because its declaration was absent. The generic Bootstrap starter layout is maintained in this repository and has no Figma source in the project. Add the explicit, reason-bearing exception marker without changing any other layout byte or behavior.

Task metadata: plan layout-design-source; type task; acceptance_criteria [declare the actual layout design source, preserve all existing markup and values]; relevant_documentation design-source-of-truth rule and official design-source gate; testing_requirements [official changed-surface gate, byte comparison of remaining layout]; skills [lisa-tdd-implementation, lisa-git-commit]; learnings [a generic repository-owned layout still needs an explicit declaration when design-source enforcement is enabled]. Verification type documentation, command official design-source-gate.mjs against the batch change, expected changed layout is admitted as a reason-bearing exception. The original gate failure is the RED control; this comment-only correction needs no additional behavioral test.

Full delivery is in progress. Operator requires stable LOCAL independent-review/evidence handoff BEFORE commit/push/PR. Root reviews first. Keep #81 open/in-progress, binding and ignored private context retained.

Root consumed complete exact 221581-byte bundle before planning. Private SHA256 74fb3082cc038bb6b34e66990ad3e42a2506b88273c0ba56b6d82fc7b8858d78. Roster is .lisa/roster/CodySwannGT-railsstarter-81.md. First resolver completed claimed/open worktree binding. Historical hold text remains intact, current direct-session operator authorization takes precedence and is reported honestly, not as trusted tracker-human release evidence.

Flow: Implement / Build task with browser asset compatibility behavior. Target is authored Assumption: dev mapped by ignored validator config dev→main. Main is the sole permanent integration branch. Live base 31517fd9aa0c4baf3e5eaecc3d9f7b4c5f271a44. Feature codex/81-bootstrap-cdn-sri begins at inherited committed35acfcf. Integrate already committed #65 head2b7af506 by normal fast-forward if researcher ancestry/relevance readback proves it; retain original trailers and #81 binding. No source copied from root dirty upgrade.

Scope: current supported Bootstrap5.3.x exact CSS/bundleJS CDN URLs, SRI values, anonymous crossorigin, ticket-required layout/navbar/flash/importmap journey and meaningful source-coupled regression codification. Existing navbar lacks expansion affordance, so a minimal accessible toggler/collapse wrapper is within authored acceptance. Flash setup uses owned synthetic runtime fixture consuming real partial, not a shipped demonstration page. No new design treatment or arbitrary design values. No persistent state changes.

Exclude other audit fixes, broad Lisa apply/adoption, CI edits, Ruby/dependency-tree upgrades, AWS calls/writes and production deployment. MySQL optional only if actual journey needs data. Never load unsafe rails_helper against ambient database. If required, newly owned MySQL8.4 with unique primary/queue/cache/cable names and positive ownership/identity checks before any mutations. Owned server/process resources only, preserve siblings/shared scratch.

Sequence and ownership:
1. Explorer records official primary-source version selection, exact fetched network bytes/SRI/CORS and every required reference, source journey and runtime/runner discovery in .lisa/research-81.md.
2. Independent generic native verifier loads Lisa verification contracts and proves genuinely interactive browser control availability. Unavailable required access stops immediately, no weaker/test-only substitution.
3. Root syncs/integrates committed #65 ancestry and updates access/results before starting builder.
4. Worker changes only required source references and minimum navbar markup, records .lisa/implementation-81.md and source hashes. Prepare owned SDK-fixture Rails runtime with no live AWS and no unsafe helper/schema operations.
5. Independent verifier executes exact authored success journey, records network/browser CSS/JS/SRI, observable style/JS/importmap, screenshots/console, deliberately corrupts SRI in owned temporary negative-control copy, observes blocked resource, then restored success. Verifier compares final source hashes independently.
6. Only after actual PASS, worker invokes lisa-codify-verification contract to encode same source-bound journey in project's configured runner, meaningful negative control observed failing and restored green, behavior scenario/coverage-map/gate as required by bdd-e2e-coverage. No detached asset imitation.
7. Independent verifier reviews codification reachability and final artifact/network identity, records schema v2 verdict with honest uncommitted source manifest identity. Root reviews complete final diff and evidence and writes local handoff.
8. Record native cumulative usage snapshots keyed once per actual session UUID, canonical Lisa usage serializer stable entry IDs. Never sum or doublecharge older snapshots. Cleanup only positively owned process/resources, retain binding/context.

Evidence boundaries: source/network hashes support artifact/CORS compatibility only, never browser behavior. Interactive controller evidence establishes browser loading/blocking and UI state. Runner execution codifies that observed journey only when real source-bound control is falsified. Source manifest binds uncommitted file bytes because HEAD excludes local changes. CI, commit, PR, merge, remote deploy proof remain pending due to operator local stopping point, never described as complete.

Every flagged inventory comment is addressed: original audit/hold and no-PR caveats retained, latest explicit authorization local stop enforced, parent/upstream scope preserved, #65 source integration only and original status/trailers preserved. No rejection evidence present requiring a different remedy.

## Task metadata

{
  "plan": "bootstrap-cdn-sri-81-local-handoff",
  "type": "task",
  "work_item_context": "/Users/cody/.codex/worktrees/769f/railsstarter/.lisa/work-item-context.md",
  "comment_inventory": [
    "- CodySwannGT/railsstarter#81 comment 5970062869 | CodySwannGT | 2026-10-03T14:24:24Z | Original audit filing was held; authored acceptance, remedy and evidence obligations remain authoritative | flags=constraint|decision",
    "- CodySwannGT/railsstarter#81 comment 5981821084 | CodySwannGT | 2026-10-04T15:55:18Z | Codex direct-session operator authorization reported; hold history retained; stop before commit/push/PR | flags=constraint|decision",
    "- CodySwannGT/railsstarter#60 comment 5970057524 | CodySwannGT | 2026-10-03T14:23:43Z | Audit coordination epic with native children and related cross-repository audit | flags=constraint|decision",
    "- CodySwannGT/railsstarter#65 comment 5970058812 | CodySwannGT | 2026-10-03T14:23:52Z | Related work history and implementation/evidence status \u2014 see complete comment in context | flags=constraint|decision",
    "- CodySwannGT/railsstarter#65 comment 5974206797 | CodySwannGT | 2026-10-03T22:35:38Z | Related work history and implementation/evidence status \u2014 see complete comment in context | flags=constraint|decision",
    "- CodySwannGT/railsstarter#65 comment 5974207778 | CodySwannGT | 2026-10-03T22:35:45Z | Related work history and implementation/evidence status \u2014 see complete comment in context | flags=decision",
    "- CodySwannGT/lisa#4330 comment 5970057729 | CodySwannGT | 2026-10-03T14:23:44Z | Related work history and implementation/evidence status \u2014 see complete comment in context | flags=constraint|decision"
  ],
  "acceptance_criteria": [
    "Current supported Bootstrap 5.3.x CSS/JS load in actual starter browser with valid integrity and crossorigin",
    "Navbar expansion and real dismissible flash work while unrelated importmap modules initialize",
    "Owned temporary corrupt-SRI negative control is blocked at browser boundary, followed by restored success"
  ],
  "relevant_documentation": ".lisa/research-81.md (research in progress), authored complete context, current Lisa Implement/verify/codify contracts",
  "testing_requirements": [
    "Independent interactive actual Rails browser proof and network/SRI diagnostics",
    "Codify successful journey in native configured runner after actual pass, source-bound controls observed red then restored green",
    "Run only necessary scoped checks; named PR CI execution remains pending at mandated local stop"
  ],
  "skills": [
    "lisa-implement",
    "lisa-verify",
    "lisa-verification-lifecycle",
    "lisa-codify-verification"
  ],
  "learnings": [],
  "required_access": [
    {
      "tool": "GitHub tracker/source",
      "probe": "resolver authenticated complete terminal #81/#60/#65/lisa#4330 reads",
      "status": "pass"
    },
    {
      "tool": "Official Bootstrap docs/CDN",
      "probe": "researcher official docs/version/release and exact asset bytes fetch",
      "status": "pass"
    },
    {
      "tool": "Interactive browser controller",
      "probe": "independent Playwright MCP live example.com navigation and snapshot succeeded",
      "status": "pass"
    },
    {
      "tool": "Owned Rails local runtime",
      "probe": "owned actual Rails localhost63736 returns200, authored SDK fixtures consumed and database connections prohibited in owned fixture runtime",
      "status": "pass"
    }
  ],
  "verification": {
    "type": "ui-recording",
    "command": "interactive browser controller navigates owned Rails localhost, records network CSS/JS/SRI evidence, clicks navbar toggler and real flash close, reads importmap initialized modules, repeats on owned corrupt-SRI copy then restored app",
    "expected": "success has usable Bootstrap CSS/JS, expanded navbar, flash removed, importmap initialized and no integrity errors; corrupt resource is blocked and its behavior unavailable; restoration returns full success"
  }
}

## Sanitized comment inventory
- CodySwannGT/railsstarter#81 comment 5970062869 | CodySwannGT | 2026-10-03T14:24:24Z | Original audit filing was held; authored acceptance, remedy and evidence obligations remain authoritative | flags=constraint|decision
- CodySwannGT/railsstarter#81 comment 5981821084 | CodySwannGT | 2026-10-04T15:55:18Z | Codex direct-session operator authorization reported; hold history retained; stop before commit/push/PR | flags=constraint|decision
- CodySwannGT/railsstarter#60 comment 5970057524 | CodySwannGT | 2026-10-03T14:23:43Z | Audit coordination epic with native children and related cross-repository audit | flags=constraint|decision
- CodySwannGT/railsstarter#65 comment 5970058812 | CodySwannGT | 2026-10-03T14:23:52Z | Related work history and implementation/evidence status — see complete comment in context | flags=constraint|decision
- CodySwannGT/railsstarter#65 comment 5974206797 | CodySwannGT | 2026-10-03T22:35:38Z | Related work history and implementation/evidence status — see complete comment in context | flags=constraint|decision
- CodySwannGT/railsstarter#65 comment 5974207778 | CodySwannGT | 2026-10-03T22:35:45Z | Related work history and implementation/evidence status — see complete comment in context | flags=decision
- CodySwannGT/lisa#4330 comment 5970057729 | CodySwannGT | 2026-10-03T14:23:44Z | Related work history and implementation/evidence status — see complete comment in context | flags=constraint|decision

## Gate updates

Native independent Playwright MCP interactive access proved via live navigation/snapshot. Existing Ruby3.4.8 bundle satisfies Gemfile when narrow subprocess PATH selects installed Ruby. Root normal ff-only main sync already up to date, then ff-only integrated exact committed #65 head2b7af50617a8e3758ac1523e7e29b8d369db347d, whose original Work-Item/Co-authored trailers remain. #81 official binding remains unchanged. No new commit created. Baseline CSS5.3.3 declared SRI mismatches actual fetched bytes, JS matches; actual browser baseline capture required before source update.

## Research and implementation gate handoff

Read full .lisa/research-81.md, SHA256087f8698033a25e1c8acdf21412c36edbe6e9660593ce879b90420dea80952b3. Official5.3 docs/versions/twbs release select5.3.8, network bytes independently hashlib/OpenSSL and official-tag matched. CurrentCSS5.3.3 SRI is invalid. Existing authored DependencySmoke fixture consumption supports database-free actual Rails boot. Existing RSpec/Capybara/Selenium source-bound runner selected, web-only BDD scope. No design source/value change, persistent state or live AWS requirement. User policy/guard/CI exclusions override adding/wiring new guard scripts: run existing absolute shipped BDD gate, retain wiring gap for later delivery. Independent browser baseline must precede source edit, actual success must precede codification. Native thread-limit refused worker spawn, updated roster before reassigning completed resolver to generic bounded builder role within same actual team.

## Actual empirical acceptance and codification handoff

Owned database-free Rails runtime http://127.0.0.1:63736 consumed authored SDK fixtures with AWS stubbing and no MySQL/schema helpers. Actual native independent Playwright verifier observed baseline CSS SRI block before edit, then final5.3.8 CSS/JS successful loading and network byte hashes matching research, navbar expansion, real flash dismissal, initialized Stimulus/Turbo and real Home navigation. Separate owned actual-source single-character CSS and JS SRI copies both produced explicit browser blocks at respective boundaries, observable missing styles/inert controls, followed by restored source success. Source hash remained7b7839ba36a3c46f5401965561db1760ff9c287ed562aca0d12121843506920d (2558bytes). Exact inputs/artifacts for mandatory codification are .lisa/verification-81.md and evidence/81/*. Builder now codifies that passed journey. No test-run-only or mirror substitution. CDN availability is a disclosed external test dependency because exact immutable source URLs are exercised; no vendored/imitation asset is shipped.
