---
name: active-job-best-practices
description: Best practices for Rails Active Job with Solid Queue. Use when writing new background jobs, refactoring existing jobs, or when a job has mixed responsibilities, inline business logic, non-idempotent design, or missing error handling. Applies patterns - single-responsibility jobs, argument serialization, idempotent design, retry/discard strategies, queue management, recurring schedules, job concerns, and service delegation.
---

# Rails Active Job Best Practices

Jobs should be thin wrappers that deserialize arguments, delegate to a service object or model method, and handle errors. Each job does one thing. If a job has conditionals, complex logic, or multiple responsibilities, it needs refactoring.

## Decision Framework

Read the job file and classify each block of code:

| Code type | Extract to | Location |
|---|---|---|
| Business logic, multi-step operations, data transformations | Service object | `app/services/` |
| Shared retry policies, logging, instrumentation | Job concern | `app/jobs/concerns/` |
| Complex query building or data fetching | Query object | `app/queries/` |
| Recurring schedule configuration | `config/recurring.yml` | — |
| Queue and worker thread configuration | `config/queue.yml` | — |
| Argument setup, queue assignment, delegation to service | Keep on job | — |

## Patterns

### Single-Responsibility Jobs

Each job performs exactly one operation. If a job does multiple things, split it into separate jobs or extract the orchestration into a service object.

Before:

```ruby
class ProcessOrderJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    order.update!(status: :processing)
    order.line_items.each { |li| li.update!(reserved: true) }
    OrderMailer.confirmation(order).deliver_now
    InventoryService.new.reserve(order)
    Analytics.track("order_processed", order_id: order.id)
  end
end
```

After:

```ruby
class ProcessOrderJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    Orders::ProcessOrder.new(order_id).call
  end
end
```

### Argument Serialization

Pass record IDs, not ActiveRecord objects. Active Job serializes arguments to JSON — passing objects causes deserialization failures when the record changes or is deleted between enqueue and execution.

```ruby
# Wrong — passes ActiveRecord object
ReportJob.perform_later(@report)

# Correct — passes ID
ReportJob.perform_later(@report.id)

# Correct — multiple scalar arguments
NotificationJob.perform_later(user_id, event_type, metadata.to_json)
```

When a job needs multiple related IDs, use keyword arguments for clarity:

```ruby
class AssignmentNotificationJob < ApplicationJob
  queue_as :default

  def perform(assignee_id:, assigner_id:, record_type:, record_id:)
    assignee = User.find(assignee_id)
    assigner = User.find(assigner_id)
    record = record_type.constantize.find(record_id)

    Notifications::AssignmentNotifier.new(
      assignee: assignee,
      assigner: assigner,
      record: record
    ).call
  end
end
```

### Idempotent Design

Jobs must be safe to run multiple times with the same arguments. Solid Queue guarantees at-least-once delivery, so a job may execute more than once after retries or infrastructure restarts.

```ruby
class SyncInventoryJob < ApplicationJob
  queue_as :default

  def perform(product_id)
    product = Product.find(product_id)

    # Idempotent — sets absolute value, not relative
    product.update!(stock_count: ExternalInventory.fetch_count(product.sku))
  end
end
```

Anti-patterns that break idempotency:

```ruby
# Wrong — relative increment, doubles on retry
product.update!(stock_count: product.stock_count + incoming_quantity)

# Wrong — sends duplicate emails on retry
UserMailer.welcome(user).deliver_now

# Correct — guard against duplicate delivery
unless user.welcome_email_sent?
  UserMailer.welcome(user).deliver_now
  user.update!(welcome_email_sent_at: Time.current)
end
```

### Error Handling and Retries

Configure `retry_on` and `discard_on` in `ApplicationJob` for common errors, and override in specific jobs when needed. Always enable the commented-out defaults in `ApplicationJob`:

```ruby
# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError
end
```

For job-specific errors:

```ruby
class ImportDataJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
  retry_on Faraday::ConnectionFailed, wait: 30.seconds, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(import_id)
    Imports::ProcessImport.new(import_id).call
  end
end
```

Retry strategies:

| Strategy | Use when |
|---|---|
| `wait: :polynomially_longer` | Transient failures (network, deadlocks) — backs off exponentially |
| `wait: N.seconds` | Known recovery time (rate limits, external service cooldown) |
| `attempts: 3-5` | Most transient errors |
| `attempts: 1` + `discard_on` | Record-not-found or deserialization — retrying won't help |

### Queue Management

Name queues by category, not by job name. Configure queue priorities and worker threads in `config/queue.yml`.

```ruby
class ImportDataJob < ApplicationJob
  queue_as :default
end

class SendNotificationJob < ApplicationJob
  queue_as :email
end

class GenerateReportJob < ApplicationJob
  queue_as :reporting
end
```

Queue naming conventions:

| Queue name | Purpose |
|---|---|
| `default` | General-purpose work |
| `email` | Mailer delivery jobs |
| `reporting` | Long-running report generation |
| `census` | Periodic data collection |

### Recurring Jobs with Solid Queue

Schedule recurring jobs in `config/recurring.yml`. Solid Queue manages the schedule — no cron or external scheduler needed.

```yaml
production:
  daily_cleanup:
    class: CleanupExpiredRecordsJob
    schedule: at 3am every day
  sync_inventory:
    class: SyncInventoryJob
    args: [42]
    schedule: every 15 minutes
  heartbeat:
    command: "puts 'I am alive'"
    schedule: every 30s
```

Key rules for recurring jobs:

- Use `class:` to reference the job class, not `command:` (reserve `command:` for simple one-liners)
- Recurring jobs receive no arguments by default — use `args:` if needed
- Set `queue:` to override the job's default queue
- Recurring jobs must be idempotent — they will run again on the next schedule tick

### Job Concerns

Extract shared behavior into concerns when multiple jobs need the same cross-cutting logic.

```ruby
# app/jobs/concerns/measurable.rb
module Measurable
  extend ActiveSupport::Concern

  included do
    around_perform :measure_duration
  end

  private

  def measure_duration
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
  ensure
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    Rails.logger.info { "#{self.class.name} completed in #{duration.round(2)}s" }
  end
end
```

```ruby
class ImportDataJob < ApplicationJob
  include Measurable

  queue_as :default

  def perform(import_id)
    Imports::ProcessImport.new(import_id).call
  end
end
```

Good candidates for concerns:

- Execution timing and metrics
- Structured logging
- Error reporting to external services
- Deduplication guards

### Delegating to Service Objects

Jobs are entry points, not implementations. The job's `perform` method should find records, call a service, and handle the result. All business logic lives in the service.

```ruby
# app/jobs/generate_report_job.rb
class GenerateReportJob < ApplicationJob
  queue_as :reporting

  retry_on Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 3

  def perform(report_id)
    Reports::GenerateReport.new(report_id).call
  end
end

# app/services/reports/generate_report.rb
module Reports
  class GenerateReport
    def initialize(report_id)
      @report = Report.find(report_id)
    end

    def call
      data = fetch_data
      document = build_document(data)
      @report.file.attach(io: document, filename: "#{@report.name}.pdf")
      @report.update!(status: :completed, completed_at: Time.current)
    end

    private

    def fetch_data
      # query logic
    end

    def build_document(data)
      # PDF generation logic
    end
  end
end
```

## Testing

### Test job behavior with `perform_now`

```ruby
RSpec.describe ProcessOrderJob, type: :job do
  describe "#perform" do
    it "delegates to the service object" do
      service = instance_double(Orders::ProcessOrder, call: true)
      allow(Orders::ProcessOrder).to receive(:new).with(42).and_return(service)

      described_class.perform_now(42)

      expect(service).to have_received(:call)
    end
  end
end
```

### Test enqueue behavior

```ruby
RSpec.describe ProcessOrderJob, type: :job do
  describe "enqueueing" do
    it "enqueues on the default queue" do
      expect {
        described_class.perform_later(42)
      }.to have_enqueued_job(described_class).with(42).on_queue("default")
    end
  end
end
```

### Test retry and discard behavior

```ruby
RSpec.describe ImportDataJob, type: :job do
  describe "error handling" do
    it "retries on connection failure" do
      expect(described_class.new).to have_attributes(
        # Verify retry_on is configured by checking job metadata
      )

      perform_enqueued_jobs do
        described_class.perform_later(1)
      end
    end

    it "discards when record is not found" do
      expect {
        described_class.perform_now(999_999)
      }.not_to raise_error
    end
  end
end
```

## Refactoring Process

1. **Read the entire job** and identify every line of business logic in `perform`.
2. **Check argument types** — replace any ActiveRecord objects with IDs.
3. **Verify idempotency** — ensure running the job twice produces the same result.
4. **Extract business logic** into a service object. The job's `perform` should be 1-5 lines.
5. **Add error handling** — configure `retry_on` for transient failures, `discard_on` for permanent ones.
6. **Assign a categorical queue** — use a meaningful queue name, not the default unless appropriate.
7. **Extract shared behavior** into concerns if the same pattern appears in 3+ jobs.
8. **Create or update tests** — test delegation, enqueueing, and error handling separately.

## What NOT to Do

- Don't put business logic in `perform` — delegate to a service object.
- Don't pass ActiveRecord objects as arguments — pass IDs and re-fetch in the job.
- Don't rely on job execution order — jobs may run out of order or concurrently.
- Don't use `perform_now` in production code to bypass the queue — it defeats the purpose of background processing.
- Don't create a separate queue per job — group jobs into categorical queues.
- Don't rescue `StandardError` broadly in `perform` — use `retry_on` and `discard_on` instead.
- Don't use `after_commit` callbacks to enqueue jobs unless you understand the transaction boundary — prefer explicit enqueue in the service or controller.
- Don't schedule recurring jobs with cron when Solid Queue's `config/recurring.yml` handles it natively.
