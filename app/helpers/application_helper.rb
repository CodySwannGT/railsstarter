# frozen_string_literal: true

# Shared view helpers available to all templates.
#
# Provides flash message styling utilities for the application layout.
module ApplicationHelper
  # Maps flash message names to Bootstrap alert CSS classes.
  #
  # @param name [String, Symbol] the flash message key
  # @return [String] the Bootstrap alert class suffix
  def flash_alert_class(name)
    case name.to_s
    when 'success', 'notice' then 'success'
    when 'alert', 'info' then 'info'
    when 'warning' then 'warning'
    else 'danger'
    end
  end
end
