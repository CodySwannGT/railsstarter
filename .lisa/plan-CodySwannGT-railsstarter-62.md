# #62 local build plan

Adopt the exact published create-only helper as a project-owned migration. Preserve support loading and existing RSpec integrations. Add reaching subprocess boundaries and a physical isolated-MySQL request witness.

Base carrier: `32655203ffec2cb30643b080de90bede5566e294`, retained through normal fast-forward. Original #67 donor `d63792e49ac9ef4306fff8b379dc7c3036209ab8` is normally merged for zero-AWS no-opt-in boot. All original Work-Item ancestry remains.

```gherkin
Scenario: Required successful outcome
  Given RAILS_ENV=development or staging and synthetic non-test database settings
  When a subprocess requires rails_helper
  Then it exits before connecting, migrating or cleaning any database

Scenario: Boundary or failure outcome
  Given test settings for every configured database
  When the new safety specs and a request spec run
  Then only the test databases are accessed
```

Prerequisites: published Lisa4.69.3 helper SHA256`b12256cd12baf050efc960417ad426ffaa2d7de13f2dda4523c6fdcd5be9a582`; supported installed Ruby/Bundler; owned isolated MySQL8.4. No live AWS/real production database access.

Research: retained carrier supports FactoryBot/Shoulda/transactional fixtures, default discovery rejects zero examples, coverage floors80/70. Preserve support loader while replacing unsafe old boot order. Correct the old request expectation for unconditional AWS calls to the reviewed #67 zero-AWS contract.

Additional combined-discovery defect: the #68 Unicode witness passed standalone but replaced global ActiveRecord pools with its disposable target and removed that target before later Rails fixtures. Builder owns its minimal process/state isolation fix while preserving all four physical Unicode checks; independent review and unfiltered default discovery must pass afterward.

Compatibility scope from empirical full discovery: reconcile only the shared runtime/browser smoke fixtures and direct assertions with the reviewed #67 zero-AWS no-opt-in contract. Preserve real #64/#81 image, database, asset/UI, isolation and SDK-stub behavior. Official action checker uses an ignored exact installed-script fallback until #65 common adoption; ordinary Docker/Node tool paths are supplied only to narrow test subprocesses. No guard source/policy changed.

Private evidence: `.lisa/automations/runs/issue62-build/`, mode0600 raw logs with concise hashed manifest. Roster: `.lisa/roster/CodySwannGT-railsstarter-62.md`. Handoff/comment inventory remains in the private context. Historical hold/comments preserved under current operator authorization. No fabricated human release.

Learnings config default `.lisa/PROJECT_LEARNINGS.md` remains absent. Reuse bounded compiled empty projection from resolver, never raw ledger context.

Scope ends at normal independently verified scoped donor commit. #65 owns shared push/PR/CI/release/terminal closure. Binding and private context remain until delivery.

```json
{
  "work_item_ref": "CodySwannGT/railsstarter#62",
  "context_path": "/Users/cody/.codex/worktrees/c659/railsstarter/.lisa/work-item-context.md",
  "context_sha256": "529945aaeb0f2106c9752e56d75cfbf4b56d5efbb69cf08a1fc79a0537afddbe",
  "skills": [
    "lisa-implement",
    "lisa-track",
    "lisa-github-read-issue",
    "lisa-github-claim"
  ],
  "learnings": [
    {
      "kind": "learning",
      "note": "Physical disposable database witnesses must isolate ActiveRecord global state from unfiltered discovery."
    },
    {
      "kind": "learning",
      "note": "Coverage-enabled default test runner disables optional Bootsnap compile caches before coverage startup."
    }
  ],
  "required_access": [
    {
      "tool": "GitHub #62/source and published npm4.69.3",
      "status": "pass",
      "probe": "live issue/merged PR4342 and exact authenticated public npm tarball digest"
    },
    {
      "tool": "Ruby3.4.11/Bundler",
      "status": "pass",
      "probe": "installed correct runtime with narrow configured resolver: ruby -v; bundle check"
    },
    {
      "tool": "owned isolated MySQL8.4",
      "status": "pass",
      "probe": "independent verifier bundled mysql2 SELECT version/current database/current user on owned namespace: MySQL8.4.11"
    }
  ],
  "verification": {
    "status": "passed-local-default-discovery",
    "named_specs": [
      "spec/safety",
      "spec/requests/database_isolation_spec.rb",
      "spec/requests/home_spec.rb"
    ],
    "coverage_floors": {
      "line": 80,
      "branch": 70
    },
    "empty_discovery_rejection": true,
    "independent_current_byte_review": true,
    "physical_all_database_roles_and_request": true,
    "default_command": "bundle exec rspec",
    "examples": 165,
    "failures": 0,
    "line_coverage": 98.31,
    "branch_coverage": 93.24,
    "external_bootsnap_disable_flags": false,
    "cleanup": "verified-owned-resources-absent"
  },
  "tasks": [
    {
      "role": "explorer",
      "scope": "read-only exact published helper/carrier/zeroAWS research",
      "status": "complete-local"
    },
    {
      "role": "worker",
      "scope": "owned helper migration + subprocess spies + physical request witness",
      "status": "complete-local"
    },
    {
      "role": "default",
      "scope": "owned prerequisite and independent empirical acceptance/cleanup",
      "status": "complete-local"
    },
    {
      "role": "explorer",
      "scope": "independent current-byte review after builder return",
      "status": "complete-local"
    }
  ]
}
```

Default runner integration: external DISABLE_BOOTSNAP=1 was earlier diagnostic setup, not proof of plainRSpec. The test runner must disable the built-in compile cache before coverage initializes, preserve load-path cache, and prove unfiltered `bundle exec rspec` without either externally supplied disable flag. Current native actors missing at resume; retained reviews reused and one bounded builder reconstituted under unchanged default config.
