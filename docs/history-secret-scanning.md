# Introduced history scanning

The original Lefthook pre-push route runs `scripts/lisa-rails-prepush.mjs` with Git's actual ref-update input. It requires both Work-Item traceability and the introduced-history credential scan. Scanning includes intermediate introduced commits, so deleting a credential from the final tree does not make that pushed history safe. New branches and multiple ref updates use their actual Git ranges.

Lisa owns the scanner helpers. Durable changes belong upstream and arrive through full Lisa apply. The scanner requires the official Gitleaks 8.30.1 executable and verifies its platform-specific checksum before using it. A same-version replacement executable does not qualify.

Provision the pinned executable explicitly, then make it available on PATH:

```sh
mkdir -p "$HOME/.local/bin"
node scripts/lisa-history-secrets.mjs provision "$HOME/.local/bin/gitleaks"
export PATH="$HOME/.local/bin:$PATH"
```

The scan runs offline after provisioning. Missing or damaged tooling, unavailable Git objects and failed vendor Git children refuse the push. Diagnostics redact findings and withhold raw bootstrap/vendor errors. Repair the reported prerequisite or introduced history and retry the original push route.

The CI caller also declares the required history property. Its status context must be required in the live main ruleset, alongside Work-Item traceability; a green workflow declaration alone does not prove merge enforcement.

Independent local verification on 2026-10-06 covered 18 controls using the genuine pinned executable, including a credential removed from the latest commit, intermediate/new-branch/multiple-ref history, clean updates, missing objects and damaged tooling. Those controls are separate from terminal push-hook and hosted CI verification.

## Historical checksum evidence

Eight privacy-reviewed audit and owned-fixture reports are retained as exact regular Git files under `.lisa/history-secret-preimages/sha256/`. Each filename is the SHA256 of its complete contents. They preserve the public preimages needed to authenticate checksum records in earlier committed audit reports, including references to temporary evidence files that hosted runners cannot access.

The catalogue is committed evidence for checksum identity. Reports retain their original dates and limited observations; current acceptance still requires the original push and hosted checks. Released upstream classifier support must be adopted before the original scan can use these preimages. Private session and credential stores remain excluded from Git and deployment images.
