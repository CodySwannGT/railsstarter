# frozen_string_literal: true

# Base controller inherited by all application controllers.
#
# Provides flash-to-header translation for XHR responses
# and restricts access to modern browsers.
class ApplicationController < ActionController::Base
  include FlashHeaders

  allow_browser versions: :modern
end
