# Dependency updates

The starter's permanent npm dependency is `@codyswann/lisa`. Dependabot checks Bundler, GitHub Actions and Bun daily, with a limit of ten open pull requests per ecosystem. Bun coverage includes Lisa and future ordinary JavaScript dependencies. The repository maintainer (currently `CodySwannGT`) owns review, npm lock synchronization and Lisa's full-template apply before merging a Lisa update.

Lisa's installed plugin provides a local `SessionStart` updater. With the plugin enabled in a supported coding runtime, it checks npm's latest release at startup, updates an eligible clean checkout and runs a full apply. CI does not update Lisa. A dirty checkout, a shared `node_modules` symlink or an explicitly disabled updater leaves the update for a later eligible session. Preserve existing work and use an isolated checkout when necessary.

The repository maintainer (currently `CodySwannGT`) reviews Lisa updates at session startup and reviews the npm release at least weekly when no supported startup updater is running. Read the registry version with `npm view @codyswann/lisa@latest version`. Use the published package, rather than installing a Git branch or an unpublished candidate. Installing a package does not apply its project templates: run the installed Lisa CLI's explicit full apply and inspect its full-apply receipt and doctor result.

The startup updater and weekly maintainer check also support Lisa updates. Reuse an existing Dependabot proposal when it selects the intended release rather than creating a second update PR. Installing a newer Lisa package alone does not perform its required full-template apply.

## Keep both lockfiles coherent

This starter commits `bun.lock` and `package-lock.json`. Bun installs project JavaScript dependencies. The npm lock also supplies the Lisa tool-version metadata used by setup and CI. Lisa's local updater chooses one package manager, so review both lockfiles after an update.

After the Bun update, synchronize the npm lock with `npm install --package-lock-only --ignore-scripts`. Confirm that the manifest, installed Lisa and both locks resolve the intended released version and integrity. Verify the normal frozen Bun installation and a frozen npm installation in a separate disposable checkout. A successful package installation or apply receipt alone does not prove that both locks agree.

Keep dependency changes in their own ordinary commit, with the real work-item binding and required trailer. Batch that commit with related changes in a PR into `main`. The assembled PR still needs its current-head quality, MySQL, behavior, README walkthrough, credential and review checks before merge. Update tooling does not grant review approval or permission to skip those checks.

## Dependabot for JavaScript packages

The configured `bun` ecosystem covers the shared manifest and committed text `bun.lock`. The daily Bundler and GitHub Actions entries remain enabled. Do not schedule a competing npm updater for the same manifest.

GitHub applies a three-day cooldown to version updates by default. The Bun entry excludes `@codyswann/lisa` from that cooldown so the daily check can propose a newly published Lisa release. Other Bun packages retain the three-day delay. Review and apply the selected released package before merging. See [GitHub's cooldown reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#cooldown).

The Bun updater updates the manifest and Bun lock; it does not synchronize the npm lock. The maintainer must regenerate `package-lock.json` using the command above, inspect the intended cohort and verify both frozen installers before merging an update. Keep Lisa's full-apply ownership explicit when selecting dependencies for automated updates. Do not assume a dependency-version PR applied Lisa's templates.

Lisa's genuine Dependabot tracking policy is being delivered under issue #82. The chosen policy uses a GitHub-authenticated Dependabot-created PR as the entire update's tracking record, including maintainer amendments. `.lisa.config.json` opts in with `workItem.dependabotTracking: "pull-request"`; the released reusable workflow must support that option before enabling delivery is merged. Its default behavior remains separate issue tracking. Preserve the required checks and ordinary protected merge. Do not use a bot-like branch, author email or body marker to exempt an ordinary contribution.

The enabling configuration must reach `main` before Dependabot reads it. For the initial acceptance run, install the compatible released reusable workflow first and let Dependabot propose the real outstanding Lisa package update. Keep the existing SDK until that proposal, then review the current npm release, synchronize the npm lock and run its full-template apply on the update branch. Do not add an unnecessary dependency merely to generate a test PR. Complete the genuine update's current-head checks and ordinary merge before declaring issue #82 complete.

The old custom producer caller, configuration and direct test fixture are being removed. Do not restore them or dispatch the custom producer from historical acceptance notes. This guide records the current direction, not a claim that new Dependabot coverage has already passed hosted acceptance.
