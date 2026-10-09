@gh-78 @ratified-request-security-acceptance @web
Feature: Request policy protected starter navigation
  Enforced CSP and host policy preserve the browser journey with a shared anonymous quota.
  Runtime deployments explicitly configure their supported ingress trust boundary.

  @BDD-REQUESTCSP-001
  Scenario: Nonced importmap and precise asset sources preserve real navigation
    Given the real Rails page with an enforced CSP and a fresh request nonce
    When required styles and modules load and I expand the navbar and dismiss flash
    Then Home navigation uses Turbo without unexpected CSP violations

  @BDD-REQUESTCSP-002
  Scenario: Unauthorized scripts and styles cannot execute or apply
    Given the configured real Rails page in Chrome
    When absent or incorrect nonce content, inline handlers and unlisted origin assets are inserted
    Then enforced violations occur and the content is blocked

  @BDD-REQUESTCSP-003
  Scenario: Required nonce and source controls reach the browser boundary
    Given disposable layouts and controller policies for this fixture
    When the importmap nonce or required Bootstrap source grants are removed
    Then actual module initialization or Bootstrap rendering fails with CSP violations

  @BDD-REQUESTSRI-004
  Scenario: Bootstrap stylesheet integrity remains enforced
    Given the original source CDN stylesheet with one corrupted integrity character
    When the real page loads in Chrome
    Then the stylesheet is rejected while unrelated importmap initializes

  @BDD-REQUESTSRI-005
  Scenario: Bootstrap script integrity remains enforced
    Given the original source CDN script with one corrupted integrity character
    When the real page loads and I use navbar and flash controls
    Then script integrity rejection prevents those Bootstrap interactions

  @BDD-REQUESTQUOTA-006
  Scenario: Physical quota preserves protected navigation
    Given the real starter with the cache-database quota enabled
    When Chrome loads required resources and uses navbar flash and Turbo navigation
    Then request nonces and enforced CSP remain compatible without violations

  @BDD-REQUESTQUOTA-007
  Scenario: Quota integration preserves the nonce failure control
    Given the actual cache-database quota and a fixture with the importmap nonce removed
    When Chrome loads that fixture
    Then module execution fails and enforced CSP violations are observed

  @BDD-REQUESTQUOTA-008
  Scenario: Established quota rejection leaves exact health available
    Given Chrome and an actual shared cache-database counter
    When anonymous same-origin requests establish the configured quota
    Then Chrome observes HTTP429 while exact health remains HTTP200

  @gh-82 @BDD-BROWSERCENSUS-009
  Scenario: A genuine Chrome leaf departure permits a fresh owned census
    Given a real Chrome journey with captured native anchors and a later owned leaf
    When that leaf exits between the profile census and native metadata observation
    Then positive native absence permits a new complete census with the original anchors
    And the departed process is never admitted and owned browser cleanup is verified

  @gh-82 @BDD-BROWSERCENSUS-010
  Scenario: Later process admission uses only the validated fresh pair
    Given a first census containing a positively departed leaf and a fresh census containing a new owned leaf
    When the fixture selects later browser processes after validating the fresh profile and metadata pair
    Then it selects the new leaf and never retains the departed candidate

  @gh-82 @BDD-BROWSERCENSUS-011
  Scenario: Missing observations alone cannot authorize another census
    Given an incomplete census whose missing process is live or whose qualified observation fails
    When the fixture classifies the missing native metadata
    Then it refuses admission without another census or any process signal
    And malformed or duplicate profile rows and native metadata errors also refuse before absence classification

  @gh-82 @BDD-BROWSERCENSUS-012
  Scenario: Departure recovery requires complete ancestry and a non-anchor leaf
    Given an incomplete census with an absent retained anchor or an absent ancestor needed by a surviving member
    When the fixture validates all available members before any absence probe
    Then missing anchors and incomplete or cyclic ancestry refuse without admission or process signals
    And departure of an entire branch is refused rather than classified as leaf departure

  @gh-82 @BDD-BROWSERCENSUS-013
  Scenario: Departure never hides an identity violation or permits PID replacement
    Given native and profile identities retained across census attempts
    When a birth parent owner or process group changes or a positively absent PID reappears
    Then the fixture refuses admission without process signals even if a fresh pair is coherent
    And a present identity violation mixed with missing metadata refuses before any absence probe

  @gh-82 @BDD-BROWSERCENSUS-014
  Scenario: Every census attempt and final validation shares one finite deadline
    Given the original two-second census budget and one-second per-observation limit
    When absence checks repeated departure churn or strict final validation exhaust the shared deadline
    Then the fixture refuses admission without resetting the budget or accepting a partial pair
    And no process signal is authorized by the failed collection
