# frozen_string_literal: true

require 'active_storage/service'

# Active Storage namespace extended only with the unavailable asset-build service.
module ActiveStorage
  # The exact dummy-secret asset task can construct this service without a
  # provider client. It cannot serve an upload, even inside that build process.
  class Service::UploadBuildOnlyService < Service
    # Raised by every upload/read/delete/URL operation in the build-only service.
    class Unavailable < StandardError; end

    def initialize(**)
      super()
    end

    %i[upload update_metadata download download_chunk open compose delete delete_prefixed exist?
       url url_for_direct_upload headers_for_direct_upload].each do |operation|
      define_method(operation) do |*_, **_, &_block|
        raise Unavailable, 'Active Storage uploads are unavailable during assets:precompile'
      end
    end
  end
end
