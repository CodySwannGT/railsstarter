# frozen_string_literal: true

# Compatibility entrypoint. AWS configuration is loaded once, before environment files,
# by AwsBootstrap in config/application.rb. Asset builds never perform remote lookup here.
