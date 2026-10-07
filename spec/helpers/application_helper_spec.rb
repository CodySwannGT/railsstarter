# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/synthetic_aws'
require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  { success: 'success', notice: 'success', alert: 'info', info: 'info', warning: 'warning',
    error: 'danger', synthetic_unknown: 'danger' }.each do |name, css_class|
    it "maps #{name} flash messages to #{css_class} alerts" do
      expect(helper.flash_alert_class(name)).to eq(css_class)
      expect(helper.flash_alert_class(name.to_s)).to eq(css_class)
    end
  end
end
