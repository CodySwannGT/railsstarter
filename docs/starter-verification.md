# Verifying a renamed application

Set deployment and telemetry identities explicitly for each application and environment. The verification scripts have no default AWS profile, region, cluster, service, or telemetry identity.

```bash
export AWS_PROFILE=example-staging
export AWS_REGION=eu-west-1
export ECS_CLUSTER=example-cluster
export ECS_SERVICE=example-web
export OTEL_SERVICE_NAME=example-web-staging

bin/verify-schema
bin/verify-telemetry health
bin/verify-telemetry slow
bin/verify-telemetry errors
bin/verify-telemetry services
bin/verify-telemetry trace 1-00000000-000000000000000000000000
```

Both scripts accept a positional profile instead of `AWS_PROFILE`. For telemetry, place the profile after the command, or after the trace ID for `trace`. Missing or blank required settings fail before any AWS call. Telemetry also requires the AWS CLI and `jq`.

`OTEL_SERVICE_NAME` is the exact runtime and X-Ray service name. The OpenTelemetry initializer does not append the Rails environment. Include any environment suffix in the configured value itself, and use the same value when running the telemetry script. Leaving `OTEL_EXPORTER_OTLP_ENDPOINT` unset or blank keeps telemetry disabled. Enabling the endpoint requires a nonblank `OTEL_SERVICE_NAME`.

Health, slow-request, and fault queries include an X-Ray service filter. The service-graph API has no filter-expression argument, so the script displays only nodes with the configured name and edges between those selected nodes. Trace IDs can span applications, so the trace view displays only segment documents with the configured name. These scoped views do not show a complete cross-service dependency graph or trace.

`bin/verify-schema` invokes `bin/rails db:verify_schema` through ECS Exec on a running service task. It requires ECS Exec access, the Session Manager plugin, and local Ruby to parse the task's JSON output. Locally, run `bin/rails db:verify_schema` against the intended database configuration. Verification uses the application's configured primary schema and reports pending migrations and table differences. It does not create or load schema tables.

The task honors the primary database's `schema_dump` setting, Rails' database directory, and the `SCHEMA` override. It supports static Rails-generated Ruby schema dumps. SQL dumps, disabled dumps, unreadable files, and dynamic schema declarations fail with directions to configure or regenerate the dump using `bin/rails db:schema:dump`. All declared tables, including Solid Queue, Cache, and Cable tables when present in that primary dump, are checked. Only Rails' internal migration metadata tables are excluded from the actual table list.

The JSON result contains `status`, `expected_count`, `actual_count`, `missing`, `extra`, and `pending_migrations`. A missing or extra table, pending migration, or invalid schema produces a failing exit status. Schema-reading errors also include an actionable `error` diagnostic.

The reusable Solid Queue worker listens to `"*"`, covering application queues and Solid Queue recurring tasks. Applications can narrow that setting when they need dedicated workers.

CloudFormation export loading retains the asset-domain mapping and its dummy-compilation guard. Unused cache and domain-queue mappings have been removed. The named SMTP delivery subclass retains standard Mail SMTP behavior and existing settings. It does not implement additional encryption or application-specific routing.

The reviewed cleanup also removes an unused branded image, replaces inherited stylesheet header wording, and removes a Brakeman ignore for an absent job. CSS tokens and rendering rules remain unchanged. No new warning suppressions are introduced. Generic scaffold placeholders remain available for application setup.

Run the isolated verification specs without starting Rails or contacting a provider:

```bash
bundle exec rspec spec/telemetry spec/schema_verification
bundle exec brakeman --no-pager --quiet --format json
```

The telemetry fixtures exercise the actual shell parser and AWS CLI argument protocol. Initializer specs use installed OpenTelemetry classes and CloudFormation SDK stub responses. Local tests establish these boundaries. They do not establish live provider access or deployment health.
