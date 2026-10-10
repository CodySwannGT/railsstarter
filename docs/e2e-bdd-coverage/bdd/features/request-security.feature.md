<!-- lisa-bdd-feature-projection-v1 coverage source=bdd%2Ffeatures%2Frequest-security.feature -->
# BDD behavior contract — feature coverage burndown

Source: bdd/features/request-security.feature

Traceability proves aligned automation exists, never that it ran or passed. A waiver is never coverage. Execution marked “not supplied” is unknown; “not run” means no supplied result matched this mapping. Retry outcomes retain the worst supplied result.

## Declarations

| Scenario | Behavior | Feature | Source line | Platforms | Lifecycle | Tags | Steps |
|---|---|---|---|---|---|---|---|
| BDD-REQUESTCSP-001 | Nonced importmap and precise asset sources preserve real navigation | Request policy protected starter navigation | 7 | web | required | BDD-REQUESTCSP-001, gh-78, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-REQUESTCSP-002 | Unauthorized scripts and styles cannot execute or apply | Request policy protected starter navigation | 13 | web | required | BDD-REQUESTCSP-002, gh-78, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-REQUESTCSP-003 | Required nonce and source controls reach the browser boundary | Request policy protected starter navigation | 19 | web | required | BDD-REQUESTCSP-003, gh-78, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-REQUESTSRI-004 | Bootstrap stylesheet integrity remains enforced | Request policy protected starter navigation | 25 | web | required | BDD-REQUESTSRI-004, gh-78, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-REQUESTSRI-005 | Bootstrap script integrity remains enforced | Request policy protected starter navigation | 31 | web | required | BDD-REQUESTSRI-005, gh-78, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-REQUESTQUOTA-006 | Physical quota preserves protected navigation | Request policy protected starter navigation | 37 | web | required | BDD-REQUESTQUOTA-006, gh-78, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-REQUESTQUOTA-007 | Quota integration preserves the nonce failure control | Request policy protected starter navigation | 43 | web | required | BDD-REQUESTQUOTA-007, gh-78, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-REQUESTQUOTA-008 | Established quota rejection leaves exact health available | Request policy protected starter navigation | 49 | web | required | BDD-REQUESTQUOTA-008, gh-78, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-BROWSERCENSUS-009 | A genuine Chrome leaf departure permits a fresh owned census | Request policy protected starter navigation | 55 | web | required | BDD-BROWSERCENSUS-009, gh-78, gh-82, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-BROWSERCENSUS-010 | Later process admission uses only the validated fresh pair | Request policy protected starter navigation | 62 | web | required | BDD-BROWSERCENSUS-010, gh-78, gh-82, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-BROWSERCENSUS-011 | Missing observations alone cannot authorize another census | Request policy protected starter navigation | 68 | web | required | BDD-BROWSERCENSUS-011, gh-78, gh-82, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-BROWSERCENSUS-012 | Departure recovery requires complete ancestry and a non-anchor leaf | Request policy protected starter navigation | 75 | web | required | BDD-BROWSERCENSUS-012, gh-78, gh-82, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-BROWSERCENSUS-013 | Departure never hides an identity violation or permits PID replacement | Request policy protected starter navigation | 82 | web | required | BDD-BROWSERCENSUS-013, gh-78, gh-82, ratified-request-security-acceptance, web | Given; When; Then |
| BDD-BROWSERCENSUS-014 | Every census attempt and final validation shares one finite deadline | Request policy protected starter navigation | 89 | web | required | BDD-BROWSERCENSUS-014, gh-78, gh-82, ratified-request-security-acceptance, web | Given; When; Then |

## Tracker references

| Scenario | Reference | URL |
|---|---|---|
| BDD-REQUESTCSP-001 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-REQUESTCSP-002 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-REQUESTCSP-003 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-REQUESTSRI-004 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-REQUESTSRI-005 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-REQUESTQUOTA-006 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-REQUESTQUOTA-007 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-REQUESTQUOTA-008 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-BROWSERCENSUS-009 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-BROWSERCENSUS-009 | gh-82 | https://github.com/CodySwannGT/railsstarter/issues/82 |
| BDD-BROWSERCENSUS-010 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-BROWSERCENSUS-010 | gh-82 | https://github.com/CodySwannGT/railsstarter/issues/82 |
| BDD-BROWSERCENSUS-011 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-BROWSERCENSUS-011 | gh-82 | https://github.com/CodySwannGT/railsstarter/issues/82 |
| BDD-BROWSERCENSUS-012 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-BROWSERCENSUS-012 | gh-82 | https://github.com/CodySwannGT/railsstarter/issues/82 |
| BDD-BROWSERCENSUS-013 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-BROWSERCENSUS-013 | gh-82 | https://github.com/CodySwannGT/railsstarter/issues/82 |
| BDD-BROWSERCENSUS-014 | gh-78 | https://github.com/CodySwannGT/railsstarter/issues/78 |
| BDD-BROWSERCENSUS-014 | gh-82 | https://github.com/CodySwannGT/railsstarter/issues/82 |

## Mapped evidence and execution

| Scenario | Runner | Platforms | File | Evidence | Evidence resolution | Execution | Run |
|---|---|---|---|---|---|---|---|
| BDD-REQUESTCSP-001 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | enforces request nonces while scripts, styles, navbar, flash and Turbo navigation work | resolved | not supplied |  |
| BDD-REQUESTCSP-002 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | blocks absent nonces, inline handlers and an unlisted script and style origin | resolved | not supplied |  |
| BDD-REQUESTCSP-003 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | detects missing importmap nonce and required CDN source controls in real Chrome | resolved | not supplied |  |
| BDD-REQUESTSRI-004 | rspec-capybara-selenium | web | spec/browser/bootstrap_assets_spec.rb | blocks a corrupt stylesheet integrity while unrelated importmap initializes | resolved | not supplied |  |
| BDD-REQUESTSRI-005 | rspec-capybara-selenium | web | spec/browser/bootstrap_assets_spec.rb | blocks corrupt script integrity and cannot expand navigation or dismiss flash | resolved | not supplied |  |
| BDD-REQUESTQUOTA-006 | rspec-capybara-selenium | web | spec/browser/request_rate_limits_spec.rb | preserves nonces, required resources and navbar flash Turbo navigation with the physical quota enabled | resolved | not supplied |  |
| BDD-REQUESTQUOTA-007 | rspec-capybara-selenium | web | spec/browser/request_rate_limits_spec.rb | enforces the existing missing-importmap-nonce failure control with the physical quota enabled | resolved | not supplied |  |
| BDD-REQUESTQUOTA-008 | rspec-capybara-selenium | web | spec/browser/request_rate_limits_spec.rb | observes real HTTP quota rejection in Chrome while exact health remains available | resolved | not supplied |  |
| BDD-BROWSERCENSUS-009 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | admits only a fresh complete census after a genuine later Chrome leaf departs between native observations | resolved | not supplied |  |
| BDD-BROWSERCENSUS-010 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | recomputes later admission from the fresh pair instead of retaining a departed candidate | resolved | not supplied |  |
| BDD-BROWSERCENSUS-011 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses duplicate profile members before attempting an absence retry | resolved | not supplied |  |
| BDD-BROWSERCENSUS-011 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses failed absence observations instead of replacing missing metadata | resolved | not supplied |  |
| BDD-BROWSERCENSUS-011 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses live omitted native metadata without obtaining another census | resolved | not supplied |  |
| BDD-BROWSERCENSUS-011 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses malformed profile rows mixed with missing metadata | resolved | not supplied |  |
| BDD-BROWSERCENSUS-011 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses native metadata observation errors before any absence classification | resolved | not supplied |  |
| BDD-BROWSERCENSUS-012 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses a missing retained anchor before any absence probe | resolved | not supplied |  |
| BDD-BROWSERCENSUS-012 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses a surviving member whose ancestry requires the missing member | resolved | not supplied |  |
| BDD-BROWSERCENSUS-012 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses cyclic surviving ancestry mixed with a missing leaf | resolved | not supplied |  |
| BDD-BROWSERCENSUS-012 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses departure of an entire branch instead of treating missing ancestors as leaves | resolved | not supplied |  |
| BDD-BROWSERCENSUS-013 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses any reappearance of a PID after positive absence | resolved | not supplied |  |
| BDD-BROWSERCENSUS-013 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses cross-census #{field} drift even when the fresh pair agrees | resolved | not supplied |  |
| BDD-BROWSERCENSUS-013 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses mixed departure and a present #{field} violation before probing absence | resolved | not supplied |  |
| BDD-BROWSERCENSUS-014 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | does not reset the original observation budget after departure | resolved | not supplied |  |
| BDD-BROWSERCENSUS-014 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | exhausts one shared budget under repeated departure churn without admitting a partial pair | resolved | not supplied |  |
| BDD-BROWSERCENSUS-014 | rspec-capybara-selenium | web | spec/browser/request_security_spec.rb | refuses admission when strict final validation consumes the remaining observation budget | resolved | not supplied |  |

## Local obligations

| Scenario | Platform | Configured runners | Traceability | Waived | Gap |
|---|---|---|---|---|---|
| BDD-REQUESTCSP-001 | web | rspec-capybara-selenium | covered | no | no |
| BDD-REQUESTCSP-002 | web | rspec-capybara-selenium | covered | no | no |
| BDD-REQUESTCSP-003 | web | rspec-capybara-selenium | covered | no | no |
| BDD-REQUESTSRI-004 | web | rspec-capybara-selenium | covered | no | no |
| BDD-REQUESTSRI-005 | web | rspec-capybara-selenium | covered | no | no |
| BDD-REQUESTQUOTA-006 | web | rspec-capybara-selenium | covered | no | no |
| BDD-REQUESTQUOTA-007 | web | rspec-capybara-selenium | covered | no | no |
| BDD-REQUESTQUOTA-008 | web | rspec-capybara-selenium | covered | no | no |
| BDD-BROWSERCENSUS-009 | web | rspec-capybara-selenium | covered | no | no |
| BDD-BROWSERCENSUS-010 | web | rspec-capybara-selenium | covered | no | no |
| BDD-BROWSERCENSUS-011 | web | rspec-capybara-selenium | covered | no | no |
| BDD-BROWSERCENSUS-012 | web | rspec-capybara-selenium | covered | no | no |
| BDD-BROWSERCENSUS-013 | web | rspec-capybara-selenium | covered | no | no |
| BDD-BROWSERCENSUS-014 | web | rspec-capybara-selenium | covered | no | no |

## Waived obligations

| Scenario | Platforms | Runner | Owner | Reason | Ticket | Expires |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — |

Waiver recording dates (complete records are retained in JSON):

| Scenario | Recorded at |
|---|---|
| — | — |

## Associated retirements

| Scenario | Platforms | Approved by | Reason | Ticket | Recorded at |
|---|---|---|---|---|---|
| — | — | — | — | — | — |

The matching JSON leaf retains complete local declarations, mappings, waiver and retirement records. Current global inventory, counts, floor evaluations and defects are published by the runtime CI summary.
