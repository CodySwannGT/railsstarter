# Starter capability profiles: decision spike

## Status and scope

Recommendation pending human choice for [#84](https://github.com/CodySwannGT/railsstarter/issues/84), under [audit parent #60](https://github.com/CodySwannGT/railsstarter/issues/60). The authored timebox is one engineering day. The spike compares capabilities and documents a proposed boundary before any future implementation.

## Evidence and frozen provenance

Starter baseline: **fb07c214ed1151c01e1ec93a00bddc581dcd68e9**. Downstream inventory: Qualis **2400282fa7e303d4000e995703eba057a0245395**. All consumer citations below pin that exact revision, rather than a changing checkout.

The supported wiki query found no substantive starter answer. Source fallback established the baseline. The downstream wiki's PostgreSQL claim conflicts with its recorded MySQL Gemfile/schema, so source takes precedence. Official publisher documentation was captured on **2026-10-05 UTC**. Mutable official URLs are retrieval snapshots, separate from consumer lock versions and empirical compatibility.

The retained full source manifest covers 1,228 starter and 3,307 Qualis blobs, with git object IDs, bytes and SHA256. Manifest SHA256: **a6482269452680baeaa7a7fe9e7ff72162ca77e56312626b69df0473ba3d0a3f**. The accepted research archive contains 105 hash-verified receipts. Research JSON SHA256: **2c474c1593dac290f7df855a855b449d2ed99ea3c8dde8f318bef1a0b5de9b10**. These are static source evidence, not runtime measurements.

## Current starter baseline

The [Gemfile][starter-gemfile] and lock record Ruby 3.4.11/Rails 8.1.4, MySQL multi-database storage, Solid Queue/Cache/Cable and Hotwire/Propshaft/importmap. The [layout][starter-layout] uses Bootstrap 5.3.8 via CDN. “Minimal” means relative to the proposed candidates, not an absence of existing framework/cloud dependencies.

[Routes][starter-routes] expose home and health. The [application controller][starter-controller], home controller, FlashHeaders, helpers and app/config/lib source contain **no current return URL consumer**. The frozen search for return_to, return_url, redirect_to, redirect_back, url_from and referer returned no matches. Rails providing redirect APIs does not establish a starter feature. None of the seven candidate groups is currently installed as a starter capability.

## Three authored options

Costs below are comparative estimates except explicitly identified source counts.

| Option | Installation and build | Maintenance and runtime | Interoperability |
|---|---|---|---|
| Minimal default | Preserve baseline. Zero candidate integrations, migrations or candidate build steps added by this document. | No new candidate costs. Consumers own later accepted features. Existing baseline obligations remain. | Keeps current Bootstrap/Hotwire and offline asset construction. Recommended. |
| Composable opt-in profiles | Integrate only accepted selections and prerequisites. Tailwind compiler or PDF browser packaging only where selected. No installer/profile engine is specified. | Selected integrations and combinations require owners and compatibility coverage. Only selected features should incur costs, subject to later verification. | Separability can avoid mandatory CSS, tenancy and browser dependencies. Combination/support burden remains unmeasured. Consider only after acceptance. |
| Single larger default | Eight direct Ruby gem names across groups. Recorded closure union has 16 names absent from starter lock, including version-drift-related rbs. Also user/role/version schema, CSS compilation and PDF Node/browser/fonts. | Every consumer inherits identity, permissions, audit privacy, CSS and browser maintenance. DB writes, client assets and browser processes add potential costs even where unwanted. | Requires deliberate Bootstrap, domain-policy and offline-build reconciliation. No evidence all consumers need it. Not recommended. |

## Recommended default and decision record

**Recommend preserving the current minimal default.** The starter has no authored identity, policy, audit, component, PDF or return URL requirement that justifies universal imports. Explicit independent opt-ins may be considered after a human accepts a concrete need. Library separability does not select reusable pieces or authorize a profile registry, generator, engine or mandatory domain framework.

| Decision field | Recorded state |
|---|---|
| Decision owner | Human product decision under existing parent |
| Human accepted options | None recorded |
| Human rejected/deferred options | Pending decision |
| Decision date and rationale | Pending |
| Research recommendation | Preserve minimal default |

## Candidate dispositions and costs

**Measured here:** locked versions, source bytes/lines/classes, declared processes/package requests and unique lock-name closures. Closure counts deduplicate platforms, do not resolve shared versions, and are not exact future installation deltas. Qualis's Ruby 4.0.2 graph differs from the starter graph. In particular, rbs reflects shared dependency/version drift.

**Estimated here:** future engineering ranges and relative maintenance/build/runtime burdens, with low confidence. Ranges assume one small generic feature plus focused coverage, excluding business migrations and production delivery. Installation time, disk/download/image size, generated CSS bytes, latency, RSS, throughput, audit bytes/event and full compatibility are **unmeasured**. Estimates are not approved work.

### Authentication — Devise

**Disposition:** consider only for an accepted identity requirement. [User modules][qualis-user] and [Devise settings][qualis-devise] record Devise 5.0.4, request authentication, recovery/session policy and bcrypt work. Static closure: six names absent from starter lock.

**Install/build estimate:** 2–5 engineering days for explicit user schema/modules/routes, recovery mail and session settings. Ruby dependencies and bcrypt native compilation add build ownership, without requiring a JS bundler or Chromium. **Maintenance:** medium/high account lifecycle, recovery, advisories and session ownership. **Runtime:** password hashing, session/DB reads and optional mail work, unbenchmarked.

**Interoperability/prerequisites:** Devise's official Rails 7+ and Turbo guidance informs error/redirect statuses. Qualis uses unprocessable_content/see_other. Exact starter installation is unverified. The consumer must choose identity/session/email policy and own coverage. Do not copy tenant/employer associations, password history, 90-day rotation or per-client activity/timeout jobs. Authentication does not define authorization.

### Authorization — CanCanCan and Rolify

**Disposition:** consider CanCanCan only for accepted permissions. Rolify is separately optional for persisted scoped roles. [Ability][qualis-ability] and [User][qualis-user] record CanCanCan 3.6.1/Rolify 6.0.1. Static closure: two absent names.

**Install/build estimate:** 1–3 days for a small deny-by-default policy and coverage. Role/join migrations only if roles are selected. No CSS/compiler/browser requirement. **Maintenance:** high semantic ownership of actions, resources and privilege changes. **Runtime:** ability construction, scoped relations and role queries, unbenchmarked.

**Interoperability/prerequisites:** explicit identity source, resource model, checks and positive/negative policy cases. Library minimum versions are not exact-combination proof. Qualis Ability references tenant/business models and plucks business IDs. TenantScoping and that policy remain consumer-owned, not starter defaults. Role administration must not imply grants.

### Auditing — PaperTrail

**Disposition:** consider selected model history only for an accepted retention/privacy need. [Actor tracking][qualis-audit] and [SoftDeletable][qualis-soft-delete] record PaperTrail 17.0.0. Static closure: two absent names including request_store.

**Install/build estimate:** 1–3 days for selected callbacks, versions schema, attribute exclusions and request/job attribution coverage. No browser/CSS build. **Maintenance:** medium/high retention, deletion, serialization and privacy ownership. **Runtime:** additional version rows and serialized attributes on enabled lifecycle events, with storage/throughput unmeasured.

**Interoperability/prerequisites:** official PaperTrail 17 supports Ruby ≥3.2/ActiveRecord 7.1–8.1, without proving this exact installation. Own primary-DB schema and explicit actor scope across requests/jobs. Identity may come from an accepted authentication option or another source. Soft deletion is a separate policy. Model history is not automatically tamper-evident compliance logging.

### Tailwind CSS

**Disposition:** consider only after a styling choice explicitly addresses Bootstrap replacement/coexistence. [CSS input][qualis-css] and [development processes][qualis-procfile] record tailwindcss-rails 4.6.0 and one CSS watch process. Input measures 27,390 bytes/738 lines, not generated CSS size. Static closure: three absent names.

**Install/build estimate:** 1–3 days for a small stylesheet/layout integration, excluding UI conversion. The Ruby platform CLI route compiles CSS without a Node bundler. **Maintenance:** medium compiler/platform, class discovery and precedence burden. **Runtime:** generated client CSS and changed base styles, with bytes/render cost unmeasured and no serving-time compiler required.

**Interoperability/prerequisites:** Propshaft/Hotwire can remain. Official Preflight resets can conflict with Bootstrap. Choose layout ownership and discoverable class strings, then verify supported build platforms. Do not copy DME branding or the consumer's Bootstrap compatibility sheet. ViewComponent does not require Tailwind.

### ViewComponent

**Disposition:** consider when reusable server-rendered components justify an abstraction. [Flash component][qualis-flash] and [status badge][qualis-badge] record view_component 4.15.0. Static inventory: six Base classes, 13 component files, 27,743 bytes. Static closure: one absent name.

**Install/build estimate:** 0.5–2 days for one generic component and rendering coverage. One Ruby gem, no schema/CSS compiler/browser requirement. **Maintenance:** low/medium API, helper/context and accessibility coverage. **Runtime:** rendering/compilation/cache abstraction, with no measured speed, boot or allocation claim.

**Interoperability/prerequisites:** official Ruby ≥3.2/Rails ≥7.1 ranges include baseline versions but do not establish empirical compatibility. Own component API and context. Qualis flash requires Tailwind and alert-dismiss Stimulus behavior. Status badge vocabulary is business-specific. Neither is selected for copying or forced view conversion.

### PDF — Grover, Chromium and optional CombinePDF

**Disposition:** consider only for an accepted HTML-to-PDF need. CombinePDF separately requires an actual merge/append need. [Web image][qualis-docker], [worker image][qualis-worker], [Grover initializer][qualis-grover] and [invoice service][qualis-invoice] record Grover 1.2.10/CombinePDF 1.0.31. Static closure: three absent names. Both images request six browser-related apt packages and mutable puppeteer-core@^22 outside package.json lock ownership.

**Install/build estimate:** 2–5 days for bounded rendering/isolation and deterministic Node/Puppeteer/browser/font packaging on actual execution images. Native/browser assets add build and architecture burden. **Maintenance:** high version pairing, fonts, timeouts, concurrency, sandbox and content/network trust ownership. **Runtime:** browser startup/processes, CPU/RAM and potential asset network requests, all unbenchmarked.

**Interoperability/prerequisites:** own HTML/assets/font access, execution placement and sandbox/network policy. Official Puppeteer guidance requires deliberate executable pairing for puppeteer-core and a usable sandbox. Non-root alone does not justify no-sandbox. Preserve offline asset construction, with no build-time cloud publishing. Do not copy tenant orientation, invoice/order services, S3/mail/job orchestration or mutable installs.

### SafeReturnTo

**Disposition:** conditional/deferred because no current starter consumer exists. [Qualis helper][qualis-return] and [caller][qualis-return-caller] supply source evidence, not an accepted guard. Static closure: zero additional gems.

**Install/build estimate:** only after acceptance, 0.5–1.5 days for a bounded Rails-native parameter/fallback contract and controller/request coverage. No expected dependency, asset, DB or browser build requirement for validation itself. **Maintenance:** low code burden with high security consequence from parser/decoding differences. **Runtime:** URL validation costs unmeasured and currently absent.

**Interoperability/prerequisites:** a real consumer, trusted fallback, decoding boundary and human-approved origin policy. Qualis checks URI.parse host plus blank/http/https scheme, without a root-path, port/userinfo, encoded/control/backslash policy. Its raw query append can occur after a fragment. The actual item_alias append caller uses a numeric ID, so no user-controlled append exploit is asserted. Rails 8.1.4 url_from's host check is not an origin guarantee. Ruby URI and browser parsing differ. Do not copy an unproven guard.

## Excluded domain imports

Tenant resolution/scoping, tenant/user/employer schema, consumer role policy, business models/controllers, DME statuses/branding and invoice cloud/mail/workflow jobs stay consumer-owned. Existing domain-labelled starter CSS is provenance debt, not authorization to import more behavior or perform cleanup in this spike.

## Conditional return URL contract

**Proposal only, pending human acceptance. The conditional capability trigger is absent today.** If a later accepted feature consumes return URLs, propose unambiguous root-relative paths and validated same-origin HTTP(S) absolute inputs reduced to local paths. Exact scheme/host/effective port must match, with no userinfo. Other authorities, protocol-relative forms and ambiguous/malformed input fall back to a fixed application-owned destination.

This stricter origin policy is itself unaccepted. Rails url_from checks host/root paths or configured allowlists, not scheme/port/userinfo equality. Redirect configuration and browser normalization matter. A trusted guard must neither grant destination authorization nor repeatedly decode attacker input.

The following **25 proposal cases are not executed tests**. Inputs use the synthetic HTTPS origin app.example.test:443. “Allow” always remains conditional on deliberate validation and a reviewed normalization contract.

| Case | Input | Proposed outcome | Later assertion |
|---|---|---|---|
| R01 | `missing, null, blank, array or object` | fallback | Accept only a nonblank scalar string; no to_s coercion of containers. |
| R02 | `/` | allow root path | Current-origin root; fixed application-owned fallback remains available. |
| R03 | `/account?tab=security#settings` | allow root path | Preserve ordinary query and fragment; no query append is required by this starter. |
| R04 | `https://app.example.test/account on HTTPS app.example.test:443` | allow after validation; emit /account | Proposed exact-origin absolute input normalized to a local path; this stricter policy is pending human acceptance. |
| R05 | `https://APP.EXAMPLE.TEST/account` | allow only after verified canonical host normalization | DNS host case is normalized deliberately, not raw string inference; emit local path. |
| R06 | `http://app.example.test/account on HTTPS origin` | fallback | Same host is not same scheme/origin. Rails url_from alone may allow it; proposed contract is stricter. |
| R07 | `https://app.example.test:8443/account on origin :443` | fallback | Same host with a different effective port is not same origin. |
| R08 | `https://app.example.test:443/account on HTTPS origin :443` | allow after validation; emit local path | Compare effective ports with deliberate canonicalization. |
| R09 | `https://evil.example.test/ or https://sub.app.example.test/` | fallback | External and subdomain hosts are not the request host. |
| R10 | `//evil.example.test/path, //app.example.test/path or ///evil.example.test` | fallback | Reject all protocol-relative/authority-leading forms, even same-host; do not infer browser interpretation. |
| R11 | `account, @evil.example.test, ?tab=1, #fragment` | fallback | Reject path-relative/query-only/fragment-only forms, not application-root paths. |
| R12 | `javascript:alert(1), data:text/html,..., ftp://app.example.test/, http:evil.example.test` | fallback | Reject non-HTTP(S), opaque or hostless absolute forms. |
| R13 | `https://app.example.test@evil.example.test/` | fallback | Actual host is external, regardless of visually trusted prefix. |
| R14 | `https://user@app.example.test/` | fallback | No userinfo accepted, even when host matches. |
| R15 | `https://app.example.test.evil.example.test/ or trailing-dot alternate host` | fallback | No suffix match or alternate textual authority without explicit normalization contract. |
| R16 | `http://[invalid or https://app.example.test:bad/` | fallback without exception escaping | Invalid parse/component/port must fail closed; no Location constructed from rejected input. |
| R17 | `/%ZZ, /% or invalid UTF-8` | fallback | Reject malformed escapes/encoding; avoid repairing attacker input. |
| R18 | `outer encoded %2F%2Fevil.example.test arrives as //evil.example.test` | fallback | Validate the parameter after the framework's normal single decoding; never validate the encoded wrapper instead. |
| R19 | `/%2f%2fevil.example.test, /%5cevil.example.test or /%252f%252fevil.example.test` | fallback | Conservative proposed path policy rejects residual encoded authority separators/backslashes and nested-escape ambiguity; no repeated decoding into a Location. |
| R20 | `/%61ccount or /search?q=hello%20world` | allow only valid, unambiguous encoding | Ordinary safe escapes may remain encoded; query values are data. A nested external URL in a query is not redirected to by this feature. |
| R21 | `literal NUL/CR/LF/TAB/DEL or leading/trailing whitespace` | fallback | Reject before parsing; browser parser trimming/removal is not a security policy. |
| R22 | `/path%0d%0aLocation:... or /path%250d%250a...` | fallback | Reject raw, escaped or nested-escape control ambiguity before emitting headers. |
| R23 | `backslash forms: \\evil.example.test, /\evil.example.test, https:\\evil.example.test` | fallback | Browser special-scheme parsing treats reverse solidus differently; no raw or residual encoded backslash accepted. |
| R24 | `/allowed?x=1#part with a future appended query field` | no append capability accepted; future URI-component edit only | If later accepted, merge separately encoded query parameters before fragment; never raw string concatenation. |
| R25 | `/path/../other or encoded dot segments` | defer canonical path review; fallback if ambiguous | Only permit a canonical local path under a reviewed future contract. Destination authorization still applies; this guard does not grant access. |

After actual acceptance and separate execution authorization, use controller/request tests for every row: local Location only, trusted fallback on rejection, no escaping parse exceptions, actual post-framework decoding, query/fragment placement and independent destination authorization. No allow_other_host:true. A different empirical actor owns execution.

## Verification and residual limits

| Authored requirement | Document evidence and limit |
|---|---|
| Successful comparison | Three options and seven candidate dispositions with source, costs, recommendation and prerequisites. Document review remains separate. |
| Accepted return URL boundary | Trigger absent. Twenty-five conditional proposals cover same-host/path, external, protocol-relative, malformed, encoded, control and backslash cases before any future implementation. No navigation accepted. |
| Baseline/success journey | Frozen source/CLI receipts and document checks reach the document boundary only. No app/DB/browser/prototype or dependency installation ran. |
| Boundary test-run evidence | Authored test-run-log: boundary-verification has no executed receipt here. Static evidence does not supply it. Separate reviewers/verifier own remaining journey interpretation and proof. |

Exact library/platform combinations, runtime behavior, installation/performance footprints and production delivery remain unestablished. Other Lisa leaves' checks/release evidence do not prove #84. This document does not claim final GO or issue completion.

## Accepted follow-ups and ownership

**Accepted options and runtime follow-up tickets: none recorded.** Add follow-ups only for options a human actually accepts, limited to their prerequisites. Engineering ranges above are estimates, not backlog.

Each accepted capability needs a maintainer and a separate implementation ticket covering its prerequisites, compatibility and verification. The decision record must identify the accepted option before that implementation begins.

## References

Immutable consumer and starter sources:

[starter-gemfile]: https://github.com/CodySwannGT/railsstarter/blob/fb07c214ed1151c01e1ec93a00bddc581dcd68e9/Gemfile#L5
[starter-layout]: https://github.com/CodySwannGT/railsstarter/blob/fb07c214ed1151c01e1ec93a00bddc581dcd68e9/app/views/layouts/application.html.erb#L17
[starter-routes]: https://github.com/CodySwannGT/railsstarter/blob/fb07c214ed1151c01e1ec93a00bddc581dcd68e9/config/routes.rb#L4
[starter-controller]: https://github.com/CodySwannGT/railsstarter/blob/fb07c214ed1151c01e1ec93a00bddc581dcd68e9/app/controllers/application_controller.rb#L8
[qualis-user]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/app/models/user.rb#L37
[qualis-devise]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/config/initializers/devise.rb
[qualis-ability]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/app/models/ability.rb#L16
[qualis-audit]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/app/controllers/concerns/paper_trail_tracking.rb#L13
[qualis-soft-delete]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/app/models/concerns/soft_deletable.rb#L18
[qualis-css]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/app/assets/tailwind/application.css#L2
[qualis-procfile]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/Procfile.dev
[qualis-flash]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/app/components/flash_messages_component.html.erb#L4
[qualis-badge]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/app/components/status_badge_component.rb#L13
[qualis-docker]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/Dockerfile#L94
[qualis-worker]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/worker.Dockerfile#L55
[qualis-grover]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/config/initializers/grover.rb
[qualis-invoice]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/app/services/invoices/pdf_generator.rb#L72
[qualis-return]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/app/controllers/concerns/safe_return_to.rb#L38
[qualis-return-caller]: https://github.com/gunnertech/qualis-app/blob/2400282fa7e303d4000e995703eba057a0245395/app/controllers/item_aliases_controller.rb

Official publisher snapshots (retrieved 2026-10-05 UTC, raw bodies/headers/hashes retained in the private research receipt inventory):

- [cancancan](https://raw.githubusercontent.com/CanCanCommunity/cancancan/develop/README.md) — snapshot SHA256 `b49903962383d963d650e772f2b019aee7e3f75c72bd5c829c80bc822dcd5057`.
- [devise](https://raw.githubusercontent.com/heartcombo/devise/main/README.md) — snapshot SHA256 `3abf2a196208d30de39fa2edc15457843333a35da41ad1ef5f72d7c5c5abe4d9`.
- [grover](https://raw.githubusercontent.com/Studiosity/grover/main/README.md) — snapshot SHA256 `954f50b2d15f8a1b8d386f3d0bc78c958c96f36f4e1e7f23c69fef28841aa494`.
- [paper-trail](https://raw.githubusercontent.com/paper-trail-gem/paper_trail/master/README.md) — snapshot SHA256 `7c563568b4c7f979e5faa7bb664123701fba06808f34296332552801898efcc8`.
- [puppeteer-browser](https://pptr.dev/guides/configuration) — snapshot SHA256 `980c19cabbe799b2821dda9ce1126a40a85e6f94ee780023b6b18b67e6a892bf`.
- [puppeteer-sandbox-resolved](https://raw.githubusercontent.com/puppeteer/puppeteer/main/docs/troubleshooting.md) — snapshot SHA256 `cf253e02ff3a0872c9567761bf8cbd00a4e3ef261c6db7adec8938c4be2f94b5`.
- [rails-redirect](https://raw.githubusercontent.com/rails/rails/v8.1.4/actionpack/lib/action_controller/metal/redirecting.rb) — snapshot SHA256 `f14112410f43fa55797ba5a6f89f0bf35cb6bb5d89de0b3c04d7553735c2b52f`.
- [rolify](https://raw.githubusercontent.com/RolifyCommunity/rolify/master/README.md) — snapshot SHA256 `06d1b536920ef332d1490bf3ef5c539f77ef1dac7101dbe343e66f40b7ed4c6b`.
- [ruby-uri](https://docs.ruby-lang.org/en/3.4/URI.html) — snapshot SHA256 `f774b10400ef18b0a695eb62726a8efb1022fadffe271a17b45d1881628d9280`.
- [tailwind-preflight](https://tailwindcss.com/docs/preflight) — snapshot SHA256 `0c9eec132ae74c3f866e8a130e0c3173ca96350cc1b4aa699002b2c78929bbd8`.
- [tailwind-rails](https://raw.githubusercontent.com/rails/tailwindcss-rails/main/README.md) — snapshot SHA256 `94377aab0b1ad8589be949c0926999a2d2fa1b9dcd4146b467c7519a93434404`.
- [url-standard](https://url.spec.whatwg.org/) — snapshot SHA256 `8e2eef304c23375141e1ac38268d5b5a54eff934c14c3175b323aab419b0dfbe`.
- [viewcomponent-compat-resolved](https://viewcomponent.org/compatibility.html) — snapshot SHA256 `cf7379c27e02055828da2632481f92eb27eef33bbbb7f68848bfc005e24c2ca3`.
- [viewcomponent-gemspec](https://raw.githubusercontent.com/ViewComponent/view_component/main/view_component.gemspec) — snapshot SHA256 `e56fa6794efa34aac582983166301658b6e9a63ab60b878c42bb86aaa21c6c43`.
- [viewcomponent](https://viewcomponent.org/guide/getting-started.html) — snapshot SHA256 `b172322b09e3273547668c9897e142c94eda68beba8087d250b8eb62071ae283`.
