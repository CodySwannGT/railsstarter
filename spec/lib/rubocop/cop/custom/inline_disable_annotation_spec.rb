# frozen_string_literal: true

require 'spec_helper'
require 'rubocop'
require_relative '../../../../../lib/rubocop/cop/custom/inline_disable_annotation'

RSpec.describe RuboCop::Cop::Custom::InlineDisableAnnotation do
  let(:config) { RuboCop::Config.new('AllCops' => { 'TargetRubyVersion' => 3.4 }) }

  def inspect_comment(source)
    processed_source = RuboCop::ProcessedSource.new(source, 3.4)
    processed_source.config = config
    processed_source.registry = RuboCop::Cop::Registry.global
    RuboCop::Cop::Team.mobilize([described_class], config, raise_error: true).investigate(processed_source)
  end

  [
    '# rubocop:disable Style/StringLiterals',
    '# rubocop:todo Style/StringLiterals',
    '# rubocop:disable Style/StringLiterals --   '
  ].each do |source|
    it "rejects a suppression without a reason: #{source}" do
      result = inspect_comment(source)

      expect(result.offenses.map(&:message)).to eq([described_class::MSG])
    end
  end

  [
    '# rubocop:disable Style/StringLiterals -- synthetic compatibility reason',
    '# rubocop:todo Style/StringLiterals -- synthetic migration reason',
    '# rubocop:enable Style/StringLiterals',
    '# an ordinary synthetic comment'
  ].each do |source|
    it "accepts justified suppression or ordinary comments: #{source}" do
      result = inspect_comment(source)

      expect(result.offenses).to be_empty
    end
  end
end
