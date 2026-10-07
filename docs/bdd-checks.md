# Browser behavior contract

The starter uses the BDD prover shipped in the locked released Lisa package.
Its package path is under `expo/copy-overwrite/scripts`, but the prover reads
this project's runner, platform and discovery configuration. No Expo runtime
or copied managed script is needed.

Run from the repository with the locked Node toolchain and an explicit comparison:

```sh
export BDD_BASE_SHA=$(git merge-base HEAD origin/main)
bun run bdd:coverage
bun run bdd:coverage:write
bun run bdd:matrix
```

The original pre-push hook checks the contract. The host-owned BDD workflow
compares against the pull request's base commit and regenerates all three
reports, then rejects a difference from their committed contents. Its exact
required context is `Behavior Checks / 🧾 BDD Behavior Contract`.

Browser examples use parenthesized `it('title')` declarations so the shipped
call-title discovery grammar sees them. Each product example is mapped.
Explicit per-title exclusions cover only harness prerequisite and cleanup unit
controls. They do not waive any of the eleven required scenario obligations.

Generated reports distinguish mapping from execution. Without `--results`
documents from an actual browser run, they say execution evidence was not
supplied. A passing contract check proves traceability and non-regression,
while the actual RSpec browser runs prove behavior. Never hand-edit the reports.
