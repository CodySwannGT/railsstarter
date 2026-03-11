# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.4.8
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Worker app lives here
WORKDIR /rails

ARG RAILS_ENV="production"
ENV RAILS_ENV=${RAILS_ENV} \
  BUNDLE_DEPLOYMENT="1" \
  BUNDLE_PATH="/usr/local/bundle" \
  BUNDLE_WITHOUT="development:test"


# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y build-essential git libvips pkg-config default-libmysqlclient-dev libyaml-dev && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock Gemfile.lisa ./
RUN bundle install && \
  rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
  bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/


# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y curl libvips default-mysql-client && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
  chown -R rails:rails db log storage tmp
USER rails:rails

# Entrypoint prepares the environment.
ENTRYPOINT ["/rails/bin/worker-docker-entrypoint"]

CMD ["./bin/jobs"]