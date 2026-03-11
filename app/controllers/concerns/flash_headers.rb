# frozen_string_literal: true

# Transfers flash messages to HTTP response headers on XHR requests.
#
# Legacy JavaScript reads flash-based status from custom response headers
# (X-Error, X-Info, X-Success, X-Message) to display notifications
# without a full page reload. Flash is discarded after transfer to
# prevent double-rendering on the next request.
module FlashHeaders
  extend ActiveSupport::Concern

  included do
    after_action :flash_to_headers
  end

  private

  # Copies flash values to response headers and discards flash for XHR requests.
  #
  # @return [void]
  def flash_to_headers
    return unless request.xhr?

    set_error_headers
    set_info_headers
    set_success_headers
    set_message_header
    flash.discard
  end

  # @return [void]
  def set_error_headers
    error_message = flash[:error]
    return if error_message.blank?

    response.headers['X-Error'] = error_message
  end

  # @return [void]
  def set_info_headers
    alert_message = flash[:alert]
    return if alert_message.blank?

    response.headers['X-Info'] = alert_message
  end

  # @return [void]
  def set_success_headers
    value = flash[:success] || flash[:notice]
    return if value.blank?

    response.headers['X-Success'] = value
  end

  # Sets X-Message to the highest-priority flash value.
  #
  # @return [void]
  def set_message_header
    value = flash[:error].presence || flash[:alert].presence || flash[:success].presence || flash[:notice].presence
    return if value.blank?

    response.headers['X-Message'] = value
  end
end
