# syntax = docker/dockerfile:1.4
# check = error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t railsstarter .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name railsstarter railsstarter

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.8
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set environment (overridable via --build-arg RAILS_ENV=staging)
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

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
ARG S3_BUCKET_NAME
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Install AWS CLI for pushing assets to S3
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y awscli

# Push precompiled assets to S3 using BuildKit secrets
RUN --mount=type=secret,id=aws_credentials \
    . /run/secrets/aws_credentials && \
    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID && \
    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY && \
    aws configure set aws_session_token $AWS_SESSION_TOKEN && \
    aws configure set region $AWS_REGION && \
    aws s3 sync public/assets s3://$S3_BUCKET_NAME/assets


# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libvips default-mysql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/thrust", "./bin/rails", "server"]
