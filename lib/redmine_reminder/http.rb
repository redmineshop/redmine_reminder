# frozen_string_literal: true

require 'httpclient'
require 'openssl'

module RedmineReminder
  # HTTP client used for webhook delivery. Redirects are refused so a public
  # HTTPS URL cannot bounce into an internal address after the SSRF check.
  module Http
    module_function

    def build_client
      client = HTTPClient.new
      client.ssl_config.cert_store.set_default_paths
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER
      client.redirect_uri_callback = proc do |_uri, _res|
        raise 'Webhook HTTP redirects are not followed'
      end
      client
    end
  end
end
