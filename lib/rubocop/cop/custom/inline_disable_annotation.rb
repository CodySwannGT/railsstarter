# frozen_string_literal: true

# RuboCop extensions for project-specific cops.
module RuboCop
  # Cop namespace for RuboCop extensions.
  module Cop
    # Custom cops specific to this project.
    module Custom
      # Enforces that every inline disable or todo directive includes a
      # justification comment after a `--` separator.
      #
      # Without this cop, developers can silently suppress warnings with no
      # audit trail. The `-- reason` suffix creates a searchable, blame-able
      # record of _why_ each disable exists.
      class InlineDisableAnnotation < Base
        # Default offense message shown when a directive lacks justification.
        MSG = 'Inline disable must include a justification comment: ' \
              '`rubocop:disable Cop/Name -- reason`'

        # Matches disable/todo directives followed by cop names, optionally
        # followed by ` -- <reason>`. Captures the reason group so we can
        # check whether it's present and non-blank.
        DIRECTIVE_PATTERN = %r{rubocop:(?:disable|todo)\s+[\w/,\s]+(?:--\s*(\S.*))?$}

        # Scans all source comments for disable/todo directives missing
        # a `-- reason` justification suffix.
        #
        # @return [void]
        def on_new_investigation
          processed_source.comments.each do |comment|
            text = comment.text

            next unless text.match?(/rubocop:(?:disable|todo)/)

            match = text.match(DIRECTIVE_PATTERN)

            add_offense(comment) unless match&.captures&.first
          end
        end
      end
    end
  end
end
