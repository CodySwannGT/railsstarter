# frozen_string_literal: true

# Synthetic CLI status control ONLY; no Docker, Rails, socket or DB operation.
# Load the actual executable under a TracePoint, replacing its boundary methods
# before invocation while retaining its real ensure/rescue/output/exit path.
fixture = File.expand_path('strong_migrations_probe.rb', __dir__)
trace = TracePoint.new(:end) do |event|
  next unless event.self.is_a?(Class) && event.self.name == 'StrongMigrationsProbe'

  event.self.class_eval do
    def observe_driver; end
    def native_preflight; end
    def verify_owner; end
    def verify_config; end
    def create_owned_database; end
    def migrate; end

    def cleanup
      raise ArgumentError, 'synthetic owned cleanup failure'
    end
  end
  trace.disable
end
ARGV.replace(%w[safe final])
trace.enable { load fixture }
