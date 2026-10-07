# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'openssl'
require 'optparse'
require 'pathname'
require 'rbconfig'
require 'securerandom'
require 'socket'
require 'yaml'

# Local consumer smoke orchestration. It never applies Lisa templates or writes to a provider.
module SmokeConsumer
  # Failure raised for bounded smoke prerequisites, ownership, observation, or execution contracts.
  class Error < StandardError; end

  # Docker label whose value identifies one exclusively allocated smoke ownership token.
  LABEL = 'io.railsstarter.consumer-smoke'

  # Read the live monotonic clock used by every smoke deadline.
  # @return [Float] monotonic seconds, independent of wall-clock adjustments
  def self.clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Retain only declared process/path/TLS variables and explicit Lisa scratch variables.
  # @return [Hash{String => String}] sanitized base for child environments
  def self.environment
    keys = %w[PATH LANG LC_ALL SYSTEMROOT SSL_CERT_FILE SSL_CERT_DIR]
    keys.concat(ENV.keys.grep(/\ALISA_SCRATCH_/))
    keys.each_with_object({}) { |key, result| result[key] = ENV[key] if ENV.key?(key) }
  end

  # Expiry is fixed; every check and polling iteration reads the live monotonic clock.
  class Deadline
    attr_reader :expires_at

    # Fix expiry at the earlier of the relative limit and outer monotonic ceiling.
    # @param seconds [Numeric] duration from the current monotonic clock
    # @param ceiling [Numeric] outer expiration time; infinity leaves only the relative limit
    def initialize(seconds, ceiling: Float::INFINITY)
      @expires_at = [SmokeConsumer.clock + seconds, ceiling].min
    end

    # Reject an expired deadline using a fresh monotonic observation.
    # @param message [String] error message for elapsed expiry
    # @return [void]
    # @raise [Error] current monotonic time reaches or exceeds expiry
    def check(message)
      raise Error, message if SmokeConsumer.clock >= expires_at
    end

    # Check expiry before each attempt, returning when the supplied predicate is truthy.
    # @param message [String] deadline error message
    # @param interval [Numeric] sleep duration between unsuccessful attempts
    # @yield attempt the bounded operation or inspect its completion
    # @yieldreturn [Object] truthy completion state, or false/nil to retry
    # @return [nil] after the predicate reports completion
    # @raise [Error] expiry is reached before an attempt
    def poll(message, interval: 0.05)
      loop do
        check(message)
        return if yield

        sleep interval
      end
    end
  end

  # Parse public smoke options and dispatch either help or the two-consumer batch.
  class Arguments
    # Retain mutable argv and configure HEAD, two safe default names, and a 1800-second limit.
    # @param arguments [Array<String>] caller-owned argv consumed by OptionParser
    def initialize(arguments)
      @arguments = arguments
      @options = { source: 'HEAD', names: %w[smoke_consumer smoke_consumer_two], timeout: 1800 }
      @parser = OptionParser.new
      configure
    end

    # Parse argv, reject leftovers, and return success after help or a completed batch.
    # @return [Integer] zero after help or successful Consumer.run
    # @raise [Error] positional arguments remain or the consumer batch fails
    # @raise [OptionParser::ParseError] an option or typed value cannot be parsed
    def run
      catch(:help) do
        @parser.parse!(@arguments)
        raise Error, 'Unexpected positional arguments' unless @arguments.empty?

        Consumer.run(@options)
        0
      end
    end

    private

    # Configure the usage banner, source/run options, and non-exiting help handler.
    # @return [void]
    def configure
      @parser.banner = 'Usage: bin/smoke-consumer [--source COMMIT] [--repository OWNER/REPO] [--names FIRST,SECOND] [--timeout SECONDS]'
      configure_source
      configure_run
      @parser.on('--help') { show_help }
    end

    # Register committed-source and declared-repository options without provider mutation.
    # @return [void]
    def configure_source
      @parser.on('--source COMMIT', 'Export committed source only; no dirty or private material') { |value| @options[:source] = value }
      @parser.on('--repository OWNER/REPO', 'Declared identity; never creates a repository, issue or backlink') { |value| @options[:repository] = value }
    end

    # Register the two-name array and integer timeout options, validated by the batch later.
    # @return [void]
    def configure_run
      @parser.on('--names FIRST,SECOND', Array, 'Two distinct, fresh local application names') { |value| @options[:names] = value }
      @parser.on('--timeout SECONDS', Integer, 'Whole run deadline including both consumers') { |value| @options[:timeout] = value }
    end

    # Print parser usage and throw the caught help result without exiting the process.
    # @return [void] control transfers to the run method catch
    def show_help
      $stdout.write("#{@parser}\n") # rubocop:disable Rails/Output -- standalone public CLI help.
      throw :help, 0
    end
  end

  # Dispatch public argv and translate smoke/option failures into a diagnostic and status one.
  # Other exception classes propagate to the caller.
  # @param arguments [Array<String>] mutable public CLI argv
  # @return [Integer] zero for help/success, one for handled contract or option failures
  def self.main(arguments)
    Arguments.new(arguments).run
  rescue Error, OptionParser::ParseError => error
    warn "consumer smoke: #{error.message}"
    1
  end
end

require_relative 'smoke_consumer/command'
require_relative 'smoke_consumer/ownership'
require_relative 'smoke_consumer/cleanup_authority'
require_relative 'smoke_consumer/toolchain'
require_relative 'smoke_consumer/rename'
require_relative 'smoke_consumer/consumer'
