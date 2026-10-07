# frozen_string_literal: true

SimpleCov.load_profile 'rails'

SimpleCov.configure do
  deprecations :raise
  coverage :line, minimum: 80
  coverage :branch, minimum: 70
  merging false
  formats :html, :json

  group 'Models', 'app/models'
  group 'Controllers', 'app/controllers'
  group 'Services', 'app/services'
  group 'Jobs', 'app/jobs'
  group 'Mailers', 'app/mailers'
  group 'Serializers', 'app/serializers'
  group 'Libraries', 'lib'

  skip '/spec/'
  skip '/config/'
  skip '/db/'
  skip '/vendor/'
end
