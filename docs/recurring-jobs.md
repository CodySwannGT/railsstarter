# Recurring job execution

[config/recurring.yml](../config/recurring.yml) defines the heartbeat command
(`puts 'I am alive'`, every 30 seconds) and `PublishCloudWatchMetricsJob` (every
minute) in development, staging and production. The test environment has no
application recurring definitions.

With the installed Solid Queue 1.3.1, a command task runs through
`SolidQueue::RecurringJob`, whose queue is `solid_queue_recurring`. A class task
without a queue override uses its job class queue. `PublishCloudWatchMetricsJob`
declares `default`. Scheduling a recurring task creates a recurring execution
and enqueues a job, but completion also requires a worker consuming that queue.

The shared worker in [config/queue.yml](../config/queue.yml) consumes all queues
with `*`, including `default`, `solid_queue_recurring` and application-defined
queues. This retains arbitrary class task consumption. Threads, process
count and polling intervals retain their previous settings.

## Required runtime check

Run the supported executable from the worktree with the project's Ruby 3.4.11
and installed Bundler dependencies on `PATH`, Python 3 and a working local Docker
engine reachable through a Unix socket:

```bash
bin/test-recurring-worker
```

The executable automatically provisions a uniquely owned physical MySQL 8.4
container with a single ephemeral `127.0.0.1` port other than 3306. It verifies
container/image IDs, nonce label and authenticated server identity, then creates
four fresh unique test databases before Rails, adapter, schema or worker access.
It supplies the internal resource manifest itself. No caller-provided manifest
or application database is required.

Before provisioning, endpoint preflight resolves the effective Docker endpoint,
requires a local Unix socket and rejects remote TCP or SSH endpoints. All Docker
commands are pinned to that socket. A default local Docker context requires no
additional caller flags.

Each scenario runs in a fresh allowlisted environment with both Rails and Rack
set to `test`, explicit synthetic database credentials and AWS metadata
disabled. Inherited URLs, hidden role inputs, AWS profiles and telemetry
configuration are discarded. Standard AWS SDK response stubs prevent live
provider access and record consumed calls. Local test boot must consume no AWS
calls without explicit bootstrap opt-in; the scheduled metrics job still must
consume its successful CloudWatch response. Every resolved database role,
including the replica, is checked against the owned resource before schema
loading. Shared Compose databases, default endpoints and remote databases are
outside this execution path.

The runtime harness in `test/runtime/recurring_worker` starts the actual
installed scheduler and workers from the current queue configuration in
asynchronous mode. It derives both task kinds from the real recurring
definitions, uses short schedules, then stops scheduling and observes persisted
executions through worker completion. The source heartbeat must execute and
write a unique completion witness. The real metrics class must finish on
`default` and consume a successful standard AWS SDK `put_metric_data` response
stub with the expected namespace, metric and unit. The consumed SDK witness
must identify the actual metrics job. This class rescues service errors, so
`finished_at` alone does not prove metrics publication.

A successful scenario requires correct task, queue and execution identities,
terminal completion, no unfinished jobs from that scenario and no remaining
scheduler or worker registrations. Four controls also run through the actual
scheduler and workers: omitting `solid_queue_recurring` must leave the command
unconsumed while the class completes, omitting `default` must leave the class
unconsumed while the command completes, a raised command error must create a
real failed execution, and a metrics SDK error must reject successful
publication even when the class records completion. Separately identified
baseline and failure records remain until the owned resource is cleaned up.
A setup error, wrong rejection reason or missing witness fails the check.
The omission controls first verify that the original worker descriptor consumes
the omitted queue, then narrow only that control's worker descriptor to the
other fixture queue. Normal acceptance uses the unchanged wildcard configuration;
an empty queue list would select all queues and is never used as an omission.

The executable exports evidence to a unique ignored
`tmp/recurring-worker-results/<nonce>.json` report before removing its private
scratch. Its final cleanup stops owned subprocesses, removes only the verified
owned container and volume, removes its unique scratch directory, and verifies
absence while preserving siblings. Exit status zero requires both the genuine
positive scenario and all four specific rejection controls to pass, followed by
verified cleanup. Failure or interrupted execution follows the same owned
cleanup boundary.

This runtime check is required separately from ordinary RSpec discovery. The
standalone harness lives outside `spec`, so ordinary collection needs no private
runtime manifest. A successful `bundle exec rspec --dry-run` proves collection
only, not application execution or coverage. The earlier manually provisioned
runtime observations are historical evidence until the supported executable is
run and independently reviewed on current source.

The #65 integration owner must invoke `bin/test-recurring-worker` in a required
CI job after Ruby/Bundler, Python and Docker setup and always upload its exported
evidence. The [required caller contract](../.lisa/implementation/CodySwannGT-railsstarter-66-ci-caller-contract.md)
records this handoff. Workflow implementation and required branch protection
belong to #65. Local proof does not establish joint CI, Linux AMD64 execution,
deployment or release acceptance.
