@web @gh-81 @ratified-bootstrap-cdn-acceptance
Feature: Starter Bootstrap assets and interactions
  The source layout and its real modules govern rendering.

  @BDD-BOOTSTRAP-001
  Scenario: Loaded CDN assets support navigation, flash and importmap
    Given the starter uses verified CDN URLs with matching integrity and anonymous crossorigin
    And a dismissible flash is rendered through the real application partial
    When the starter page loads at a compact viewport
    Then the Bootstrap stylesheet and bundle load without integrity errors
    When the user expands navigation and dismisses the flash
    Then navigation is visible and the flash disappears
    And the real importmap modules initialize and Home navigation works

  @BDD-BOOTSTRAP-002
  Scenario: Corrupt stylesheet integrity is blocked by the browser
    Given an owned copy of the source layout with only CSS integrity corrupted
    When the starter page loads
    Then the browser blocks the stylesheet and Bootstrap styles are absent
    And unrelated importmap modules initialize

  @BDD-BOOTSTRAP-003
  Scenario: Corrupt script integrity is blocked by the browser
    Given an owned copy of the source layout with only JavaScript integrity corrupted
    When the starter page loads
    Then the browser blocks the bundle
    And navigation expansion and flash dismissal do not run
    And unrelated importmap modules initialize
