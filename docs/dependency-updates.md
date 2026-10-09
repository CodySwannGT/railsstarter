# Dependency updates

The starter's permanent npm dependency is `@codyswann/lisa`. Lisa owns its update path. Keep Bundler and GitHub Actions updates in `.github/dependabot.yml`; both run daily with a limit of ten open pull requests per ecosystem.

Lisa's installed plugin provides a local `SessionStart` updater. With the plugin enabled in a supported coding runtime, it checks npm's latest release at startup, updates an eligible clean checkout and runs a full apply. CI does not update Lisa. A dirty checkout, a shared `node_modules` symlink or an explicitly disabled updater leaves the update for a later eligible session. Preserve existing work and use an isolated checkout when necessary.

The repository maintainer (currently `CodySwannGT`) reviews Lisa updates at session startup and reviews the npm release at least weekly when no supported startup updater is running. Read the registry version with `npm view @codyswann/lisa@latest version`. Use the published package, rather than installing a Git branch or an unpublished candidate. Installing a package does not apply its project templates: run the installed Lisa CLI's explicit full apply and inspect its full-apply receipt and doctor result.

After the temporary acceptance fixture is retired, this Lisa-only manifest has session-triggered updates and the maintainer's weekly fallback. No scheduled npm Bot remains. Qualifying the generic updater with a temporary package does not make that fixture the starter's permanent update coverage.

## Keep both lockfiles coherent

This starter commits `bun.lock` and `package-lock.json`. Bun installs project JavaScript dependencies. The npm lock also supplies the Lisa tool-version metadata used by setup and CI. Lisa's local updater chooses one package manager, so review both lockfiles after an update.

After the Bun update, synchronize the npm lock with `npm install --package-lock-only --ignore-scripts`. Confirm that the manifest, installed Lisa and both locks resolve the intended released version and integrity. Verify the normal frozen Bun installation and a frozen npm installation in a separate disposable checkout. A successful package installation or apply receipt alone does not prove that both locks agree.

Keep dependency changes in their own ordinary commit, with the real work-item binding and required trailer. Batch that commit with related changes in a PR into `main`. The assembled PR still needs its current-head quality, MySQL, behavior, README walkthrough, credential and review checks before merge. Update tooling does not grant review approval or permission to skip those checks.

## Additional npm packages

Lisa's generic selected npm updater requires a nonempty selection of ordinary npm packages and rejects Lisa itself. Do not create an empty caller or restore the retired scheduled `lisa-update.yml` for this Lisa-only manifest.

When a consumer adds other npm dependencies, choose its updater ownership and cadence explicitly. The supported Lisa selected updater uses exact selected versions, a host-owned caller and qualified immutable signer metadata. Qualify a genuine Actions Bot PR with canonical work-item metadata and the consumer's actual required checks before enabling that caller. Preserve Bundler and Actions coverage, existing protection rules and ordinary review. A fixture's successful publication does not establish the consumer's own checks.
