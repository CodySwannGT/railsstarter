# Selected npm updater acceptance

Issue [#82](https://github.com/CodySwannGT/railsstarter/issues/82) requires a genuine updater PR to pass this repository's protected checks. The temporary acceptance setup uses the published Lisa 4.73.0 producer at immutable commit `e451b4e04499124ad773727dfef04e3ae65d3a94`.

The owned fixture adds `is-number` 6.0.0 as a development dependency and selects its exact 7.0.0 update. Both versions are ordinary public registry packages. The fixture is removed after acceptance, together with its caller and committed selection. It does not become an application dependency or replace Lisa's full-apply update path.

The maintainer dispatches `.github/workflows/npm-updater.yml` from `main`. Its committed policy binds the actual repository and owner IDs, the genuine GitHub Actions bot ID, the immutable upstream signer, the caller path, the official Linux GH executable digest, the selected versions and the finite Rails runtime profile. The producer allocates a fresh work item before the ordinary commit and PR. It runs the original hooks with the four native MySQL roles, qualified browser and original Docker fixtures. Application code cannot receive publisher credentials.

Repository Actions PR creation must be enabled for this explicit dispatch. Record its previous setting and restore that setting after the proof. Leave repository default token permissions and all protection rules unchanged.

Read the produced PR and verify the genuine Actions bot author, canonical work-item trailer and backlink, exact manifest and lock changes, signed-provider evidence, and every current-head protected check. The required checks are:

- `CodeRabbit`
- `GitGuardian Security Checks`
- `Quality Checks / Lint`
- `Quality Checks / Code Quality`
- `Quality Checks / Security`
- `Quality Checks / Test (MySQL)`
- `Quality Checks / 🔗 Work-Item Traceability`
- `Quality Checks / History Secrets / 🔐 Introduced History Credential Leakage`
- `Behavior Checks / 🧾 BDD Behavior Contract`
- `recurring-worker-runtime`
- `Literal README Steps 1–6`

An Actions-token-created PR may need the supported close/reopen event to start its normal PR workflows. Do not substitute a synthetic event, another bot identity or a disabled check. Record terminal native checks on the actual PR head. Restore only the owned fixture and setting after collecting the proof.

The final starter keeps its Lisa-only manifest and the ownership/cadence described in [Dependency updates](dependency-updates.md). Bundler and GitHub Actions updates remain daily. Additional npm dependencies require their consumer's own committed selection and successful protected Bot PR qualification.
