# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.4.8'

gem 'aws-sdk-cloudwatch'
gem 'aws-sdk-s3'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.1.0'
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'propshaft'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 6.0'

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem 'solid_cable'
gem 'solid_cache'
gem 'solid_queue'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem 'kamal', require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem 'thruster', require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
end

group :staging, :production do
  gem 'mysql2-aws_rds_iam'
  gem 'opentelemetry-exporter-otlp'
  gem 'opentelemetry-instrumentation-all'
  gem 'opentelemetry-sdk'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'selenium-webdriver'
end

gem 'mysql2', '~> 0.5.7'

gem 'aws-sdk-secretsmanager'

gem 'aws-sdk-cloudformation'

gem 'aws-sdk-ssm'

# BEGIN: AI GUARDRAILS
eval_gemfile 'Gemfile.lisa'
# END: AI GUARDRAILS
