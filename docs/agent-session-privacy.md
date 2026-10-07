# Agent session privacy

The starter keeps the complete `.entire/` store private by default, including session data, metadata, temporary files, settings and checkpoints. Root and nested stores are ignored by Git. Inherited Entire commands have been removed from the project agent settings. The starter does not enable automatic session capture, checkpoint publishing or session uploads through those hooks. Other configured hooks remain in place.

Normal staging cannot add ignored stores. Existing tracked store paths are removed from the index without deleting local files. Git archives exclude directories named `.entire` through `.gitattributes`. The existing Docker context exclusion also keeps these stores out of image builds. Git-aware context collection must honor ignore rules. A raw filesystem upload needs its own exclusion. If a consumer adds an upload configuration such as `.easignore`, it must exclude complete root and nested stores before any upload.

## Consumer opt-in

A consumer may choose an Entire integration only through a separate, explicit review in its own repository. Define who owns session data, who may access it, retention, and every export destination before enabling capture or hooks. Review the exact hook commands and checkpoint publishing behavior with synthetic sessions. Do not enable automatic checkpoint publishing as an inherited default.

Keep private stores excluded from source control, archives, build contexts and uploads. If a consumer needs to share a session, use a separately reviewed, sanitized export outside the private store and review that artifact before publishing it. Preserve unrelated user and Lisa hooks when configuring the integration. Shared Lisa-managed hook changes belong upstream in Lisa before consumer adoption.

## Limits and verification

Ignore rules do not remove data from prior Git history, prevent deliberate forced staging, or protect an arbitrary upload that ignores these rules. Removing tracked paths preserves the current local files but future clean checkouts will not receive them. Do not open, copy or attach real session contents to an issue, a log or a review. Any history remediation requires a separate decision and does not follow from this cleanup.

Use anonymous synthetic files to verify the policy. Check `git check-ignore .entire/fake-session.json`, then exercise ordinary staging and a commit in a disposable repository with the shipped settings and ignore rules. Execute the configured hook commands with an Entire spy and confirm that unrelated hooks still run. Check a Git archive containing synthetic previously tracked stores and a disposable Docker context to confirm both exclusions. Include controls that remove an exclusion or restore an Entire hook so the check proves it detects a regression.
