# AWS configuration at boot

`config/application.rb` runs `AwsBootstrap` after Bundler loads the SDKs and before Rails evaluates environment files, `database.yml`, or initializers. Production and staging enable remote loading by default. Other environments require `AWS_BOOTSTRAP_ENABLED=true`. Set `AWS_BOOTSTRAP_ENABLED=false` when providing deployment configuration entirely through the environment.

`SECRET_KEY_BASE_DUMMY` is a hard credential-free build boundary, even if opt-in is present. An ordinary `assets:precompile` invocation also skips remote loading unless explicitly opted in. Supply `SECRET_KEY_BASE` for ordinary deployed compilation, or use the existing Docker dummy compilation contract. The original three AWS initializer filenames are compatibility shims and perform no remote lookup.

Incoming environment values always win. Missing values are filled in the order SSM, CloudFormation exports, then database secret fields. A supplied database username does not prevent loading other missing database fields. Secret ports populate `DATABASE_PORT`, which `database.yml` passes to the adapter. Supplied `SECRET_KEY_BASE` is honored, and secret lookup is skipped if all database fields and the application key are already present.

Configure selectors in the incoming environment. Remote SSM values cannot redirect the current bootstrap's clients, paths, export names or secret selections.

| Selector | Behavior |
| --- | --- |
| `AWS_REGION` | SDK region, falling back to `AWS_DEFAULT_REGION`, then `us-east-1` |
| `AWS_SSM_PATH` | Recursive decrypted path, default `/app`, normalized to a path boundary |
| `AWS_DATABASE_SECRET_ID` | Exact database secret name or ARN |
| `AWS_SECRET_KEY_BASE_SECRET_ID` | Exact application key secret name or ARN, string value |
| `AWS_DATABASE_SECRET_PREFIX` / `AWS_SECRET_KEY_BASE_SECRET_PREFIX` | Optional explicitly configured fallback, only when no exact ID exists and exactly one secret matches across all pages |
| `AWS_EXPORT_<ENV_KEY>` | Exact export name override for each mapped environment key |

The starter maps only `CLOUDFRONT_ENDPOINT=assetDomain` from CloudFormation exports. Unused Redis and domain-specific queue exports do not manufacture environment settings. Explicit incoming environment values and arbitrary valid SSM parameters retain their existing precedence. The default asset export name is optional. An explicitly selected missing asset export fails when the corresponding environment value is absent. Prefix-neighbor exports are never selected implicitly.

SSM, CloudFormation and Secrets Manager listing APIs consume every page and reject repeated pagination tokens. SSM strips the full configured path boundary, uppercases relative names and replaces `/` with `_`. Invalid keys, neighboring paths and transformed-key collisions are rejected. Secret selection rejects missing or ambiguous matches. Explicit identifiers take precedence over prefix selectors.

The database secret must be a JSON object with `username`, `password`, `dbname`, `host`, and `port`. The replica hostname is derived from the effective primary hostname when absent. Enabled deployed bootstrap requires nonempty database fields and `SECRET_KEY_BASE`. Lookup failures stop boot with the operation and exception class, excluding provider messages, secret identifiers and values. Values are applied to the environment only after loading and validation succeed.

Focused regressions run with the project-selected installed Ruby and Bundler:

```sh
bundle exec rspec --options /dev/null --format documentation spec/configuration/aws_bootstrap_spec.rb spec/configuration/aws_boot_spec.rb
bundle exec ruby spec/configuration/fixtures/aws_boot_probe.rb success
```

The isolated configuration suite avoids `rails_helper`, default database access and baseline-owned test configuration. The CLI fixture boots and eager-loads the actual application, reads actual ActiveRecord configuration, constructs the actual Mysql2 adapter without connecting, and reports port 4406 plus non-secret selection booleans and SDK request counts. Driver and socket tripwires are installed before boot. Asset scenarios execute the real Rake precompile task into a fixture-owned temporary directory and remove only that directory. No live AWS credentials or provider writes are required.
