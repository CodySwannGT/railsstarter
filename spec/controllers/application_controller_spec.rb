# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/synthetic_aws'
require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  render_views

  controller do
    def index
      params.fetch(:messages, {}).each { |name, message| flash[name] = message }
      render template: 'home/index', layout: 'application'
    end
  end

  it 'renders authored flash text with escaping on an ordinary page response' do
    get :index, params: { messages: { notice: '<script>synthetic</script>' } }

    expect(response.body).to include('alert-success', '&lt;script&gt;synthetic&lt;/script&gt;')
    expect(response.headers['X-Message']).to be_nil
    expect(flash[:notice]).to eq('<script>synthetic</script>')
  end

  it 'does not render structured flash values as message text' do
    get :index, params: { messages: { synthetic_details: ['synthetic'] } }

    expect(response.body).not_to include('id="flash_synthetic_details"')
  end

  it 'transfers all XHR status headers and gives errors message precedence' do
    get :index, params: { messages: { error: 'synthetic error', alert: 'synthetic alert',
                                      success: 'synthetic success', notice: 'synthetic notice' } }, xhr: true

    expect(response.headers).to include('X-Error' => 'synthetic error', 'X-Info' => 'synthetic alert',
                                        'X-Success' => 'synthetic success', 'X-Message' => 'synthetic error')
    get :index
    expect(flash).to be_empty
  end

  [
    [{ alert: 'synthetic alert', success: 'synthetic success' }, 'synthetic alert'],
    [{ success: 'synthetic success', notice: 'synthetic notice' }, 'synthetic success'],
    [{ notice: 'synthetic notice' }, 'synthetic notice'],
    [{ error: '', alert: '', success: '', notice: '' }, nil],
    [{}, nil]
  ].each do |messages, expected|
    it "selects the highest present XHR message for #{messages.inspect}" do
      get :index, params: { messages: messages }, xhr: true

      expect(response.headers['X-Message']).to eq(expected)
      expect(response.headers['X-Error']).to be_nil
      expect(response.headers['X-Info']).to eq(messages[:alert].presence)
      expect(response.headers['X-Success']).to eq((messages[:success] || messages[:notice]).presence)
    end
  end
end
