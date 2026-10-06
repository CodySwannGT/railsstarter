# Ruby declarations implementation: #64

Scoped builder handoff only. Native cwd `/Users/cody/.codex/worktrees/a5d8/railsstarter`, branch `task/64-align-ruby-3.4-patch`, unchanged HEAD `35acfcfd6ee6cd8ff27b1605a38cf59ed12656d1` includes exact #63 ancestor `508d0033e5feb97950782506375ce6bc1fe06306`. No commit, merge, push, PR, DB operation, image resource or lifecycle closure was performed by the builder. Other agents own research, proofs and root lifecycle artifacts.

## Delivered edits

- Gemfile, `.ruby-version` and `.mise.toml` declare exactly Ruby 3.4.11.
- Gemfile.lock metadata is `ruby 3.4.11p137`, generated from installed Ruby using actual Bundler 2.4.10 `Bundler::RubyVersion.system`. The rest of the lockfile is byte-identical. Every #63 gem version, platform and Bundler declaration is preserved.
- `Dockerfile`, `worker.Dockerfile`, `Dockerfile.local` and `worker.Dockerfile.local` use ARG 3.4.11 and official `docker.io/library/ruby:$RUBY_VERSION-slim-trixie@sha256:4677fd16f2b54ef534d18b0e34e20a15726b62c203cb996fd70297a058864c60`. Production Dockerfile bodies are otherwise unchanged. Local base keyword capitalization follows the same declaration.
- Exactly two patch strings in `.claude/rules/PROJECT_RULES.md` were updated as authorized runtime documentation. No other rule text was changed. RuboCop `TargetRubyVersion: 3.4` is correct for the minor version and its file hash is unchanged.

## Actual installation and host-native observations

Fresh owned resource root: `/tmp/railsstarter-64-builder-a4d52vq5`, pointer `.lisa/builder-root-64.json`, positive ownership `ownership.json`.

Selected interpreter: `/tmp/railsstarter-64-builder-a4d52vq5/mise-data/installs/ruby/3.4.11/bin/ruby`. Supported activated Bundler wrapper: `/tmp/railsstarter-64-builder-a4d52vq5/bundler-tools/bin/bundle`. Reproduction prefix is the selected Ruby followed by `-x <wrapper> _2.4.10_`. `ruby-bundle-env.json` defines explicit PATH, private GEM_HOME/GEM_PATH, BUNDLE_PATH, BUNDLE_USER_HOME, BUNDLE_APP_CONFIG, BUNDLE_FROZEN, explicit BUNDLER_VERSION2.4.10 and mysql2 build config. Invoke the interpreter directly; no project mise trust or safety setting was modified.

Actual commands and outcomes:

1. From `/tmp`: `env MISE_DATA_DIR=/tmp/railsstarter-64-builder-a4d52vq5/mise-data MISE_CONFIG_DIR=/tmp/railsstarter-64-builder-a4d52vq5/mise-config MISE_CACHE_DIR=/tmp/railsstarter-64-builder-a4d52vq5/mise-cache MISE_RUBY_COMPILE=false mise install ruby@3.4.11`. Exit 0. Fresh precompiled macOS runtime downloaded, checksum validated and GitHub artifact attestations verified. The log also records a Rekor public-key parsing warning before successful attestation verification; no verification setting or guard was disabled.
2. Explicit selected Ruby runs its gem installer with private GEM_HOME/GEM_PATH: `gem install bundler -v 2.4.10 --no-document`. Exit 0.
3. Actual selected interpreter + installed Bundler: `bundle install --jobs 4 --retry 2`, cwd this native worktree and `BUNDLE_FROZEN=true`. Exit 0, 55 dependencies, 236 installed gems. Public RubyGems downloads and fresh native-extension builds occurred. `bundle-install-command.json` retains the exact argv and task-isolated env values.
4. Same selected interpreter/Bundler/env: `bundle check`. Exit 0, dependencies satisfied.
5. Same selected interpreter through `bundle exec`: require mysql2, bootsnap, resolv and net/imap. Exit 0. Ruby reports `3.4.11`, patchlevel137, revision592f1ffdb3, arm64-darwin23. mysql2 0.5.7 loads the freshly built native `mysql2.bundle`; bootsnap1.22.0 loads the freshly built native `bootsnap.bundle`. Host MySQL client headers/library report9.6.0. resolv reports0.7.2 and net-imap0.6.4.1.
6. `git diff --check`. Exit 0.

`builder-verification.json` retains original direct-executable checks. The verifier identified duplicate default2.6/installed2.4 activation during later tool subprocesses, so the reproduction handoff was corrected to the RubyGems wrapper with explicit2.4.10 activation. No runtime or gem versions changed. Repeated install/check/native probes all pass0, and loaded Bundler reports2.4.10. `activated-builder-verification.json` retains corrected exact argv, elapsed times, log paths and hashes; `activated-*.log` preserve observations. `ruby-version.json`, `lock-metadata-observation.json`, `implementation-source-hashes.json`, `final-builder-identities.json` and `builder.diff` retain actual source/native/log identities. Lockfile normalization proves byte equality after replacing only the old/new Ruby metadata. All logs are sanitizer-safe and contain no copied private work-item input.

Installer logs include mise untrusted-project-config diagnostics emitted by an incidental subprocess. The explicit interpreter commands and installs still exited0, no trust mutation was made, and native loads confirm the actual selected Ruby used. This diagnostic is retained rather than hidden.

## Boundaries and retained resources

Host-native load proves the observed macOS interpreter/extensions, not Linux images, MySQL server8.4, Rails boot, SDK fixtures, runtime specs, dependency audit or lint. Independent verifier owns those probes and source/hash comparison. Linux AMD64 shipping CI remains the #65 integration boundary. Common managed Lisa adoption belongs to #65 and broad tooling to #85. No unsupported dependency bump, safety change, audit ignore or threshold weakening was made.

Retain the owned interpreter, isolated bundle, build cache and sanitized evidence for parent reproduction. No builder resource cleanup was required at this handoff. No sibling resources were touched. MLD candidates: [] pending independent review.
