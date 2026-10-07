# Migration safety

Starter defaults keep Strong Migrations checks enabled and retain
`safe_by_default`. The target compatibility version is **MySQL 8.4**. This is
the database's major/minor series, not a Rails version or a MySQL patch version.
Use an isolated MySQL 8.4 server when validating migrations. Selecting the
container image is separate from the checker compatibility setting.

Run migrations through Rails' normal migration task so the checker sees the
operations. `ActiveRecord::Schema.define` is exempt and does not validate a
migration's safety.

A non-unique index containing more than three columns is rejected:

```ruby
class AddWideIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :widgets, %i[a b c d]
  end
end
```

The gem's documented alternative uses a narrower index. Select columns and
their order for the application's actual queries:

```ruby
class AddNarrowIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :widgets, %i[d b]
  end
end
```

Validate the rejection and the narrower migration against synthetic data in a
disposable database. Observe the physical schema: rejection must leave the
schema unchanged, and success must create the intended index. A four-column
unique index is a separate boundary of this particular check, not a general
guarantee that an operation is safe for every workload.

Do not globally disable checks or set `SAFETY_ASSURED` to pass these scenarios.
An exception for a different migration requires a reviewed, documented safety
case bounded to that operation. Keep it out of shared defaults, including any
per-migration `safety_assured` block the review approves.

The named regression spec is `spec/migrations/strong_migrations_spec.rb`.
It automatically provisions its own labelled disposable MySQL **8.4.11** when
no receipt is supplied, using tracked `spec/fixtures/migrations/owned_mysql.rb`.
A Docker daemon and the exact immutable image must already be available:

```sh
docker pull mysql:8.4.11@sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242
bundle exec rspec spec/migrations/strong_migrations_spec.rb
```

For the full ordinary unfiltered suite, this tracked caller also creates four
fresh application schemas with grants restricted to those schemas, renders all
five native database roles before Rails boots, loads the existing schema files
without regenerating them, and invokes `bundle exec rspec`:

```sh
bundle exec ruby spec/fixtures/migrations/owned_mysql.rb rspec
```

The receipt starts absent and is created privately (directory 0700/file 0600)
for an ordinary `rspec-UUID` run, never an invented agent session. The immutable
image, owner labels, exact loopback port/network/volume and physical version,
UUID and hostname are verified. Missing prerequisites fail rather than skip.
Every migration runs in a fresh process through `migrate(:up)`; only its newly
created database is dropped. The server and its exclusively owned resources are
removed on successful and failed suite paths. Cleanup failure is a failing CLI
status, covered separately by a synthetic failure-status control; that control
is not a physical migration witness.

The full-suite caller installs a guard at
`Seahorse::Client::NetHttp::Handler#call`, before actual HTTP transmit. Before
boot, a real nonstubbed SSM request with explicit synthetic credentials must
reach exactly one `expected77` interception. A separate real SDK stubbed request
must serialize its intended request and return the synthetic response without
reaching terminal transport. Subsequent terminal attempts are counted and
blocked. The receipt records operation/body and synthetic response, never
credential or header values. Metadata lookup is disabled and control retries
are bounded. No scheduled jobs or application settings are suppressed.

The runner also needs Node and Docker on its child PATH, plus the official
action-pin checker available from the installed Lisa package for the existing
workflow specs. Borrowing a verified released package locally does not change
the project's declared dependency or establish clean-install/carrier CI proof.
Targeted subprocess specs alone do not exercise application coverage; use the
full suite for the unchanged coverage gate.

Sources: [Strong Migrations 2.5.2 documentation](https://github.com/ankane/strong_migrations/blob/v2.5.2/README.md#keeping-non-unique-indexes-to-three-columns-or-less)
and [database target-version guidance](https://github.com/ankane/strong_migrations/blob/v2.5.2/README.md#target-version).
