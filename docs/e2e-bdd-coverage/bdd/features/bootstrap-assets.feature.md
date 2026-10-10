<!-- lisa-bdd-feature-projection-v1 coverage source=bdd%2Ffeatures%2Fbootstrap-assets.feature -->
# BDD behavior contract — feature coverage burndown

Source: bdd/features/bootstrap-assets.feature

Traceability proves aligned automation exists, never that it ran or passed. A waiver is never coverage. Execution marked “not supplied” is unknown; “not run” means no supplied result matched this mapping. Retry outcomes retain the worst supplied result.

## Declarations

| Scenario | Behavior | Feature | Source line | Platforms | Lifecycle | Tags | Steps |
|---|---|---|---|---|---|---|---|
| BDD-BOOTSTRAP-001 | Loaded CDN assets support navigation, flash and importmap | Starter Bootstrap assets and interactions | 6 | web | required | BDD-BOOTSTRAP-001, gh-81, ratified-bootstrap-cdn-acceptance, web | Given; When; Then; When; Then |
| BDD-BOOTSTRAP-002 | Corrupt stylesheet integrity is blocked by the browser | Starter Bootstrap assets and interactions | 16 | web | required | BDD-BOOTSTRAP-002, gh-81, ratified-bootstrap-cdn-acceptance, web | Given; When; Then |
| BDD-BOOTSTRAP-003 | Corrupt script integrity is blocked by the browser | Starter Bootstrap assets and interactions | 23 | web | required | BDD-BOOTSTRAP-003, gh-81, ratified-bootstrap-cdn-acceptance, web | Given; When; Then |

## Tracker references

| Scenario | Reference | URL |
|---|---|---|
| BDD-BOOTSTRAP-001 | gh-81 | https://github.com/CodySwannGT/railsstarter/issues/81 |
| BDD-BOOTSTRAP-002 | gh-81 | https://github.com/CodySwannGT/railsstarter/issues/81 |
| BDD-BOOTSTRAP-003 | gh-81 | https://github.com/CodySwannGT/railsstarter/issues/81 |

## Mapped evidence and execution

| Scenario | Runner | Platforms | File | Evidence | Evidence resolution | Execution | Run |
|---|---|---|---|---|---|---|---|
| BDD-BOOTSTRAP-001 | rspec-capybara-selenium | web | spec/browser/bootstrap_assets_spec.rb | loads source CDN assets and expands navigation, dismisses flash and initializes importmap | resolved | not supplied |  |
| BDD-BOOTSTRAP-002 | rspec-capybara-selenium | web | spec/browser/bootstrap_assets_spec.rb | blocks a corrupt stylesheet integrity while unrelated importmap initializes | resolved | not supplied |  |
| BDD-BOOTSTRAP-003 | rspec-capybara-selenium | web | spec/browser/bootstrap_assets_spec.rb | blocks corrupt script integrity and cannot expand navigation or dismiss flash | resolved | not supplied |  |

## Local obligations

| Scenario | Platform | Configured runners | Traceability | Waived | Gap |
|---|---|---|---|---|---|
| BDD-BOOTSTRAP-001 | web | rspec-capybara-selenium | covered | no | no |
| BDD-BOOTSTRAP-002 | web | rspec-capybara-selenium | covered | no | no |
| BDD-BOOTSTRAP-003 | web | rspec-capybara-selenium | covered | no | no |

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
