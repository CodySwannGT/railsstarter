# Rails helper isolation migration

`spec/rails_helper.rb` is project owned. It explicitly adopts the create-only helper from
the published `@codyswann/lisa` 4.69.3 tarball, whose helper SHA256 is
`b12256cd12baf050efc960417ad426ffaa2d7de13f2dda4523c6fdcd5be9a582`.
The consumer retains its `spec/support/**/*.rb` loading after the isolation checks and
schema maintenance. Future Lisa applies will not overwrite this helper.

The released guard rejects supplied non-test Rails or Rack environments before host boot.
It resolves the database configuration with Rails and Active Record before application
initialization, then checks all resolved test roles, including hidden replicas, again
before schema maintenance. Names must match `LISA_TEST_DATABASE_NAME`, a project-owned
regular expression that requires a delimited `test` component. Change it only for an
explicit isolated naming policy. Trusted ERB, boot code and initializers remain executable
project code and must not connect to databases ahead of these checks.

Run `bundle exec rspec spec/safety spec/requests/database_isolation_spec.rb` with the
project's installed dependencies and an owned isolated MySQL 8.4 test namespace. The
boundary subprocesses install driver, schema and cleanup tripwires before loading actual
helper bytes and host boot code. They reject development, staging, production, Rack
mismatches and each unsafe postboot role. The exact historical helper and valid synthetic
test path reach the tripwires as controls, so zero calls cannot pass vacuously. These
controls never connect to a database.

The separate request witness physically queries `DATABASE()` and the server UUID for
primary, replica, queue, cache and cable. It exercises the real home and health endpoints
and real application reading and writing pools while collecting SQL configuration
identities. `ISSUE62_DATABASE_EVIDENCE_PATH` optionally writes the concise identity and
request trace to a private mode0600 JSON file. This physical path requires a prepared,
owned test namespace. The helper-only controls do not prove it.

Local test boot makes zero AWS requests unless bootstrap is explicitly enabled. The
coverage floors remain 80% line and 70% branch, and zero-example discovery still fails.

Default `bundle exec rspec` sets Bootsnap's supported
`DISABLE_BOOTSNAP_COMPILE_CACHE` option in `spec/spec_helper.rb` before SimpleCov
starts coverage. Bootsnap 1.22 initializes its ISeq compiler after coverage starts,
which Ruby 3.4 rejects with `should not compile with coverage`. The test runner
disables compilation caching while retaining Bootsnap's load-path cache, coverage,
the 80% line and 70% branch floors, and the zero-example discovery guard. No external
`DISABLE_BOOTSNAP` flag is required.
