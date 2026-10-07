# MySQL full-Unicode storage

New databases use `utf8mb4` and `utf8mb4_0900_ai_ci` for the primary, queue,
cache and cable connections. The same settings are explicit in the Solid schema
table definitions, so loading those schemas cannot restore three-byte `utf8mb3`
tables. The primary schema currently has no application tables. The replica
connection inherits the same connection settings.

This collation is supported by MySQL 8.0 and 8.4. MySQL 8.4 documents it as the
`utf8mb4` default. It uses Unicode Collation Algorithm 9.0, compares without case
or accent distinctions, and has `NO PAD` behavior. Four-byte characters such as
emoji round-trip without changing their UTF-8 bytes. Collation governs comparison
and sorting, so this choice can change uniqueness and ordering for existing data.
Do not assume compatibility with MariaDB or older MySQL series.

References: [MySQL 8.4 character sets](https://dev.mysql.com/doc/refman/8.4/en/charset.html),
[Unicode character sets](https://dev.mysql.com/doc/refman/8.4/en/charset-unicode-sets.html),
[connection settings](https://dev.mysql.com/doc/refman/8.4/en/charset-connection.html),
and [database defaults](https://dev.mysql.com/doc/refman/8.4/en/charset-database.html).

## Explicit isolated witness

With installed project dependencies, Docker access and a locally available
`mysql:8.4` image, run:

```sh
bundle exec ruby test/runtime/utf8mb4_spec.rb --format documentation
```

Default `bundle exec rspec` discovery includes `spec/database/utf8mb4_spec.rb`.
That wrapper executes the same four physical cases in a Ruby subprocess and fails
on a child error, missing or pending cases, absent cleanup, or a changed parent
connection pool. Standalone discovery uses a sentinel pool that is never connected.
The child cannot replace an application pool with its disposable database config.
To run only this mandatory suite wrapper, use:

```sh
bundle exec rspec spec/database/utf8mb4_spec.rb
```

The project's normal RSpec command also enforces application coverage floors.
Running only this wrapper does not exercise application code and can therefore
fail that coverage gate even when the physical cases pass. The complete combined
suite must meet the unchanged coverage floors.

Both commands require Docker and the MySQL image. Fresh CI must provision the
tested MySQL 8.4 image explicitly before RSpec, with its immutable revision owned
by the CI/image migration. A missing image fails rather than skipping the cases.
The current local proof uses cached image ID
`sha256:6ea90827b1100f8f2ae306a539f86d2c264a26ed435a2a9f75551dd5c3aeb242`.
This is local image attribution, not a fresh CI pull or AMD64 acceptance claim.

The standalone runtime witness loads Active Record directly and never boots the
application, its AWS loaders or its shared test helper. Each run creates a fresh
labeled container and scratch volume, publishes MySQL only on a unique loopback
port, validates target identity and the empty volume, and checks the actual server
version and absence of user databases. It then creates four unique test databases
using the rendered test configuration and Rails database creation options. It
checks that each is empty before loading the shipped schema.

The log records source hashes, the actual server version, an observed failure of
the original `utf8` connection against an explicitly `utf8mb4` destination, and
exact emoji round-trips through all four corrected connections. It queries
connection character sets/collation, database defaults, every loaded table and
character column, and the temporary witness column. The witness removes only its
own container and volume in an ensure block and checks their absence. Missing
Docker, image or database access fails the run. No existing application database
is used or reset. Capture this output privately when retaining target identifiers.

## Existing consumers

Changing YAML affects connections and newly created database defaults. Changing
schema declarations affects newly loaded tables. Neither change converts existing
tables or character columns. Do not run `db:reset`, reload schemas or blindly
rebuild an existing consumer database to apply this fix.

1. Inventory connection/session settings and the database, table and column
   character sets/collations for all four databases. Review the MySQL version,
   data size, index byte limits, foreign keys and each character column's type.
2. Take a verified backup and rehearse its restore into an isolated copy. Check
   how the proposed collation changes sorting, case/accent comparisons,
   trailing-space behavior and unique keys before altering production data.
3. Plan explicit, reviewed database-default and table/column conversions on that
   copy. Database defaults affect future tables only. MySQL's `CONVERT TO
   CHARACTER SET` can change character column types to retain their capacity, so
   review the resulting schema rather than applying a blanket command. Preserve
   compatible foreign-key column definitions and account for locking, rebuild
   time and disk capacity.
4. Compare the resulting schema and indexes, test the exact emoji round-trip and
   application comparisons, and rehearse rollback. Schedule the reviewed
   consumer migration with its owner and validate all four connections and
   existing tables afterward.

See [character-set conversion](https://dev.mysql.com/doc/refman/8.4/en/charset-conversion.html)
and [ALTER TABLE character-set changes](https://dev.mysql.com/doc/refman/8.4/en/alter-table.html).
No existing-consumer conversion or live provider operation is performed here.
