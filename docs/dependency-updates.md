# Dependency updates

The starter's permanent npm dependency is `@codyswann/lisa`. Lisa owns its update path. Keep Bundler and GitHub Actions updates in `.github/dependabot.yml`; both run daily with a limit of ten open pull requests per ecosystem.

Lisa's installed plugin provides a local `SessionStart` updater. With the plugin enabled in a supported coding runtime, it checks npm's latest release at startup, updates an eligible clean checkout and runs a full apply. CI does not update Lisa. A dirty checkout, a shared `node_modules` symlink or an explicitly disabled updater leaves the update for a later eligible session. Preserve existing work and use an isolated checkout when necessary.

The repository maintainer (currently `CodySwannGT`) reviews Lisa updates at session startup and reviews the npm release at least weekly when no supported startup updater is running. Read the registry version with `npm view @codyswann/lisa@latest version`. Use the published package, rather than installing a Git branch or an unpublished candidate. Installing a package does not apply its project templates: run the installed Lisa CLI's explicit full apply and inspect its full-apply receipt and doctor result.

This Lisa-only manifest has session-triggered updates and the maintainer's weekly fallback. Installing a newer Lisa package alone does not perform its required full-template apply.

## Keep both lockfiles coherent

This starter commits `bun.lock` and `package-lock.json`. Bun installs project JavaScript dependencies. The npm lock also supplies the Lisa tool-version metadata used by setup and CI. Lisa's local updater chooses one package manager, so review both lockfiles after an update.

After the Bun update, synchronize the npm lock with `npm install --package-lock-only --ignore-scripts`. Confirm that the manifest, installed Lisa and both locks resolve the intended released version and integrity. Verify the normal frozen Bun installation and a frozen npm installation in a separate disposable checkout. A successful package installation or apply receipt alone does not prove that both locks agree.

Keep dependency changes in their own ordinary commit, with the real work-item binding and required trailer. Batch that commit with related changes in a PR into `main`. The assembled PR still needs its current-head quality, MySQL, behavior, README walkthrough, credential and review checks before merge. Update tooling does not grant review approval or permission to skip those checks.

## Dependabot for additional npm packages

Use Dependabot for ordinary JavaScript dependency update PRs. GitHub supports the `bun` ecosystem for the committed text `bun.lock`. Retain the existing daily Bundler and GitHub Actions entries. Select one JavaScript ecosystem for the shared manifest rather than scheduling competing npm and Bun updates.

The Bun updater updates the manifest and Bun lock; it does not synchronize the npm lock. The maintainer must regenerate `package-lock.json` using the command above, inspect the intended cohort and verify both frozen installers before merging an update. Keep Lisa's full-apply ownership explicit when selecting dependencies for automated updates. Do not assume a dependency-version PR applied Lisa's templates.

Lisa's genuine Dependabot tracking policy is being resolved under issue #82. Until that support is delivered and verified, standard Dependabot commits without issue trailers do not pass the current Work-Item Traceability check. Preserve the required checks and ordinary protected merge. Do not use a bot-like branch, author email or body marker to exempt an ordinary contribution.

The old custom producer caller, configuration and direct test fixture are being removed. Do not restore them or dispatch the custom producer from historical acceptance notes. This guide records the current direction, not a claim that new Dependabot coverage has already passed hosted acceptance.
