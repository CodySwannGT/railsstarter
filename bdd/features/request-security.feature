@issue:CodySwannGT/railsstarter#78 @web
Feature: Request policy protected starter navigation
  Enforced CSP and host policy preserve the browser journey with a shared anonymous quota.
  Runtime deployments explicitly configure their supported ingress trust boundary.

  @BDD-REQUEST-CSP-001
  Scenario: Nonced importmap and precise asset sources preserve real navigation
    Given the real Rails page with an enforced CSP and a fresh request nonce
    When required styles and modules load and I expand the navbar and dismiss flash
    Then Home navigation uses Turbo without unexpected CSP violations

  @BDD-REQUEST-CSP-002
  Scenario: Unauthorized scripts and styles cannot execute or apply
    Given the configured real Rails page in Chrome
    When absent or incorrect nonce content, inline handlers and unlisted origin assets are inserted
    Then enforced violations occur and the content is blocked

  @BDD-REQUEST-CSP-003
  Scenario: Required nonce and source controls reach the browser boundary
    Given disposable layouts and controller policies for this fixture
    When the importmap nonce or required Bootstrap source grants are removed
    Then actual module initialization or Bootstrap rendering fails with CSP violations

  @BDD-REQUEST-SRI-004
  Scenario: Bootstrap stylesheet integrity remains enforced
    Given the original source CDN stylesheet with one corrupted integrity character
    When the real page loads in Chrome
    Then the stylesheet is rejected while unrelated importmap initializes

  @BDD-REQUEST-SRI-005
  Scenario: Bootstrap script integrity remains enforced
    Given the original source CDN script with one corrupted integrity character
    When the real page loads and I use navbar and flash controls
    Then script integrity rejection prevents those Bootstrap interactions

  @BDD-REQUEST-QUOTA-006
  Scenario: Physical quota preserves protected navigation
    Given the real starter with the cache-database quota enabled
    When Chrome loads required resources and uses navbar flash and Turbo navigation
    Then request nonces and enforced CSP remain compatible without violations

  @BDD-REQUEST-QUOTA-007
  Scenario: Quota integration preserves the nonce failure control
    Given the actual cache-database quota and a fixture with the importmap nonce removed
    When Chrome loads that fixture
    Then module execution fails and enforced CSP violations are observed

  @BDD-REQUEST-QUOTA-008
  Scenario: Established quota rejection leaves exact health available
    Given Chrome and an actual shared cache-database counter
    When anonymous same-origin requests establish the configured quota
    Then Chrome observes HTTP429 while exact health remains HTTP200
