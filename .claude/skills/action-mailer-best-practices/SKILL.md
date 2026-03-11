---
name: action-mailer-best-practices
description: Best practices for Rails Action Mailer. Use when writing new mailers, refactoring existing mailers, or when a mailer has inline business logic, missing previews, synchronous delivery, or mixed responsibilities. Applies patterns - single-responsibility mailers, parameterized mailers, deliver_later by default, mailer concerns, service delegation, previews, and structured testing.
---

# Rails Action Mailer Best Practices

Mailers should be thin wrappers that accept pre-fetched data, set instance variables for the template, and call `mail`. Each mailer method sends one type of email. If a mailer method has conditionals, data fetching, or business logic beyond simple assignment, it needs refactoring.

## Decision Framework

Read the mailer file and classify each block of code:

| Code type | Extract to | Location |
|---|---|---|
| Business logic, conditional send rules, multi-step operations | Service object | `app/services/` |
| Complex data assembly for the email body | Presenter | `app/presenters/` |
| Shared default headers, tracking, logging, error handling | Mailer concern | `app/mailers/concerns/` |
| Reusable email components (headers, footers, buttons) | Partial or ViewComponent | `app/views/shared/` or `app/components/` |
| Recipient resolution, distribution list building | Service or query object | `app/services/` or `app/queries/` |
| Attachments, subject, headers, template assignment | Keep on mailer | — |

## Patterns

### Single-Responsibility Mailers

Each mailer groups related email types for one domain concept. Each method sends exactly one email. If a mailer method conditionally sends different emails, split into separate methods.

Before:

```ruby
class UserMailer < ApplicationMailer
  def notification(user, type)
    @user = user
    case type
    when :welcome
      @message = "Welcome aboard!"
      mail(to: user.email, subject: "Welcome")
    when :password_reset
      @token = user.generate_reset_token
      mail(to: user.email, subject: "Reset your password")
    when :account_locked
      @reason = user.lock_reason
      mail(to: user.email, subject: "Account locked")
    end
  end
end
```

After:

```ruby
class UserMailer < ApplicationMailer
  def welcome(user_id)
    @user = User.find(user_id)

    mail(to: @user.email, subject: "Welcome")
  end

  def password_reset(user_id, token)
    @user = User.find(user_id)
    @token = token

    mail(to: @user.email, subject: "Reset your password")
  end

  def account_locked(user_id, reason)
    @user = User.find(user_id)
    @reason = reason

    mail(to: @user.email, subject: "Account locked")
  end
end
```

### Parameterized Mailers

Use `params` for shared context that applies to multiple mailer methods. This avoids repeating the same arguments across methods and keeps the call site clean.

```ruby
class OrderMailer < ApplicationMailer
  before_action :set_order

  def confirmation
    mail(to: @order.user.email, subject: "Order ##{@order.number} confirmed")
  end

  def shipped
    @tracking_number = params[:tracking_number]

    mail(to: @order.user.email, subject: "Order ##{@order.number} shipped")
  end

  def cancelled
    mail(to: @order.user.email, subject: "Order ##{@order.number} cancelled")
  end

  private

  def set_order
    @order = Order.find(params[:order_id])
  end
end
```

Call site:

```ruby
OrderMailer.with(order_id: order.id).confirmation.deliver_later
OrderMailer.with(order_id: order.id, tracking_number: "1Z999AA10").shipped.deliver_later
```

Use parameterized mailers when:

- Multiple methods share the same record lookup
- The mailer is called from different places with the same context
- You want cleaner call sites

Use positional arguments when:

- The method has unique, unrelated arguments
- Only one method exists on the mailer
- Arguments are simple scalars (IDs, strings)

### Always Use `deliver_later`

Queue email delivery as a background job. Synchronous delivery blocks the request and degrades user experience.

```ruby
# Wrong — blocks the request
UserMailer.welcome(user.id).deliver_now

# Correct — queues for background delivery
UserMailer.welcome(user.id).deliver_later

# Correct — with queue assignment
UserMailer.welcome(user.id).deliver_later(queue: :email)

# Correct — scheduled delivery
UserMailer.welcome(user.id).deliver_later(wait: 1.hour)
UserMailer.welcome(user.id).deliver_later(wait_until: Date.tomorrow.noon)
```

Only use `deliver_now` when:

- Running inside a background job that already handles retries
- Sending transactional email that must complete before the next step (rare)
- Testing synchronous behavior explicitly

### Pass IDs, Not Objects

Like Active Job, pass record IDs to mailer methods instead of ActiveRecord objects. Mailers serialize arguments when enqueued with `deliver_later`.

```ruby
# Wrong — passes ActiveRecord object
UserMailer.welcome(@user).deliver_later

# Correct — passes ID, mailer fetches the record
UserMailer.welcome(@user.id).deliver_later
```

### Delegate Business Logic to Services

Mailers should not decide whether to send an email. That decision belongs in a service object or the caller.

Before:

```ruby
class ReportMailer < ApplicationMailer
  def weekly_summary(user_id)
    @user = User.find(user_id)
    return unless @user.subscribed_to_weekly_summary?

    @reports = @user.reports.where(created_at: 1.week.ago..)
    return if @reports.empty?

    @summary = @reports.group_by(&:category).transform_values { |r| r.sum(&:score) }

    mail(to: @user.email, subject: "Your weekly summary")
  end
end
```

After:

```ruby
# app/mailers/report_mailer.rb
class ReportMailer < ApplicationMailer
  def weekly_summary(user_id, summary)
    @user = User.find(user_id)
    @summary = summary

    mail(to: @user.email, subject: "Your weekly summary")
  end
end

# app/services/reports/send_weekly_summary.rb
module Reports
  class SendWeeklySummary
    def initialize(user_id)
      @user = User.find(user_id)
    end

    def call
      return unless @user.subscribed_to_weekly_summary?

      reports = @user.reports.where(created_at: 1.week.ago..)
      return if reports.empty?

      summary = reports.group_by(&:category).transform_values { |r| r.sum(&:score) }
      ReportMailer.weekly_summary(@user.id, summary).deliver_later
    end
  end
end
```

### Mailer Concerns

Extract shared behavior into concerns when multiple mailers need the same cross-cutting logic.

```ruby
# app/mailers/concerns/trackable.rb
module Trackable
  extend ActiveSupport::Concern

  included do
    after_action :add_tracking_headers
  end

  private

  def add_tracking_headers
    headers["X-Mailer-Source"] = self.class.name
    headers["X-Mailer-Action"] = action_name
  end
end
```

```ruby
# app/mailers/concerns/tenant_scoped.rb
module TenantScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_tenant
  end

  private

  def set_tenant
    @tenant = Tenant.find(params[:tenant_id])
  end
end
```

Good candidates for mailer concerns:

- Tracking and analytics headers
- Tenant or organization scoping
- Default `reply_to` and `from` resolution
- Shared attachment handling
- Structured logging

### Mailer Previews

Every mailer method must have a preview. Previews let developers see rendered emails in the browser at `/rails/mailers` without sending real mail.

```ruby
# test/mailers/previews/order_mailer_preview.rb  (or spec/mailers/previews/)
class OrderMailerPreview < ActionMailer::Preview
  def confirmation
    order = Order.first || FactoryBot.build_stubbed(:order)
    OrderMailer.with(order_id: order.id).confirmation
  end

  def shipped
    order = Order.first || FactoryBot.build_stubbed(:order)
    OrderMailer.with(order_id: order.id, tracking_number: "1Z999AA10").shipped
  end

  def cancelled
    order = Order.first || FactoryBot.build_stubbed(:order)
    OrderMailer.with(order_id: order.id).cancelled
  end
end
```

Preview conventions:

- One preview class per mailer, one method per mailer method
- Use real records when available, fall back to `build_stubbed` for CI
- Name the preview method identically to the mailer method
- Previews live in `test/mailers/previews/` or `spec/mailers/previews/`

### Multipart Emails (HTML + Text)

Always provide both HTML and plain text templates. Email clients fall back to text when HTML rendering fails, and some users prefer plain text.

```
app/views/order_mailer/
  confirmation.html.erb
  confirmation.text.erb
```

Rails automatically sends multipart when both templates exist — no code changes needed.

### Attachments

Keep attachment logic in the mailer method. For complex attachment generation (PDFs, CSVs), delegate to a service and pass the result to the mailer.

```ruby
class InvoiceMailer < ApplicationMailer
  def send_invoice(invoice_id)
    @invoice = Invoice.find(invoice_id)
    pdf = Invoices::GeneratePdf.new(@invoice).call

    attachments["invoice-#{@invoice.number}.pdf"] = {
      mime_type: "application/pdf",
      content: pdf
    }

    mail(to: @invoice.user.email, subject: "Invoice ##{@invoice.number}")
  end
end
```

### Interceptors and Observers

Use interceptors to modify emails globally before delivery, and observers for post-delivery hooks.

```ruby
# config/initializers/mail_interceptors.rb

# Redirect all mail to a safe address in staging
if Rails.env.staging?
  class StagingMailInterceptor
    def self.delivering_email(message)
      message.to = ["staging-inbox@example.com"]
      message.subject = "[STAGING] #{message.subject}"
    end
  end

  ActionMailer::Base.register_interceptor(StagingMailInterceptor)
end
```

```ruby
# Logging observer
class MailLogObserver
  def self.delivered_email(message)
    Rails.logger.info { "Email delivered to=#{message.to} subject=#{message.subject}" }
  end
end

ActionMailer::Base.register_observer(MailLogObserver)
```

## Testing

### Test email content and recipients

```ruby
RSpec.describe OrderMailer, type: :mailer do
  describe "#confirmation" do
    let(:order) { create(:order) }
    let(:mail) { described_class.with(order_id: order.id).confirmation }

    it "renders the correct subject" do
      expect(mail.subject).to eq("Order ##{order.number} confirmed")
    end

    it "sends to the order's user" do
      expect(mail.to).to eq([order.user.email])
    end

    it "includes the order number in the body" do
      expect(mail.body.encoded).to include(order.number)
    end
  end
end
```

### Test delivery enqueueing

```ruby
RSpec.describe OrderMailer, type: :mailer do
  describe "#confirmation delivery" do
    let(:order) { create(:order) }

    it "enqueues the email for later delivery" do
      expect {
        described_class.with(order_id: order.id).confirmation.deliver_later
      }.to have_enqueued_mail(described_class, :confirmation)
    end
  end
end
```

### Test mailer from the service that triggers it

```ruby
RSpec.describe Orders::PlaceOrder do
  it "sends a confirmation email" do
    expect {
      described_class.new(order_params).call
    }.to have_enqueued_mail(OrderMailer, :confirmation)
  end
end
```

### Test attachments

```ruby
RSpec.describe InvoiceMailer, type: :mailer do
  describe "#send_invoice" do
    let(:invoice) { create(:invoice) }
    let(:mail) { described_class.send_invoice(invoice.id) }

    it "attaches the PDF" do
      expect(mail.attachments.count).to eq(1)
      expect(mail.attachments.first.filename).to eq("invoice-#{invoice.number}.pdf")
    end
  end
end
```

## Refactoring Process

1. **Read the entire mailer** and identify every method, callback, and private helper.
2. **Check argument types** — replace any ActiveRecord objects with IDs.
3. **Remove business logic** — conditional send rules, data fetching, and calculations go into service objects.
4. **Extract shared behavior** into concerns if the same pattern appears in 3+ mailers.
5. **Add previews** for every mailer method. Verify them at `/rails/mailers`.
6. **Add text templates** alongside HTML templates for multipart delivery.
7. **Replace `deliver_now`** with `deliver_later` in all callers (controllers, services, jobs).
8. **Create or update tests** — test content, recipients, enqueueing, and attachments separately.

## What NOT to Do

- Don't put business logic in mailer methods — the mailer should not decide whether to send.
- Don't use `deliver_now` in controllers or services — it blocks the request thread.
- Don't pass ActiveRecord objects as arguments — pass IDs and fetch in the mailer.
- Don't build complex data structures inside the mailer — use a presenter or compute in the service and pass the result.
- Don't skip mailer previews — they are the primary way to catch rendering bugs.
- Don't send HTML-only emails — always provide a text template for accessibility and deliverability.
- Don't use `after_commit` callbacks on models to trigger emails — prefer explicit delivery in the service or controller.
- Don't rescue delivery errors in the mailer — let Active Job retry mechanisms handle transient failures.
- Don't hard-code recipient addresses — use model attributes or configuration.
- Don't put URL generation logic in mailers without setting `default_url_options` — emails render outside the request cycle and need explicit host configuration.
