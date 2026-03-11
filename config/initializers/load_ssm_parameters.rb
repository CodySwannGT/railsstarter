# frozen_string_literal: true

require 'aws-sdk-ssm'

def fetch_ssm_parameters(prefix)
  client = begin
    Aws::SSM::Client.new(region: 'us-east-1')
  rescue StandardError
    nil
  end
  # Fetch parameters by path
  return unless client

  parameters = begin
    client.get_parameters_by_path({
                                    path: prefix,
                                    with_decryption: true,
                                    recursive: true
                                  }).parameters
  rescue StandardError
    nil
  end
  return unless parameters

  parameters.each_with_object({}) do |param, hash|
    # Transform SSM parameter name to environment variable name
    env_var_name = param.name.sub(prefix, '').upcase.tr('/', '_')
    hash[env_var_name] = param.value
  end
end

ssm_params = fetch_ssm_parameters('/app')

ssm_params&.each do |key, value|
  ENV[key] ||= value
end
