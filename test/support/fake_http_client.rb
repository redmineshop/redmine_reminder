# frozen_string_literal: true

module RedmineReminder
  module Test
    # Stands in for HTTPClient so webhook tests never open a socket.
    class FakeHttpResponse
      attr_reader :status, :body

      def initialize(status:, body:)
        @status = status
        @body = body
      end
    end

    class FakeHttpClient
      attr_reader :posts

      def initialize(status: 200, body: 'ok', error: nil)
        @status = status
        @body = body
        @error = error
        @posts = []
      end

      def ssl_config
        self
      end

      def cert_store
        self
      end

      def set_default_paths
        nil
      end

      def ssl_version=(_version)
        nil
      end

      def post(url, body, headers = nil)
        record(url, body, headers)
      end

      def post_async(url, body, headers = nil)
        record(url, body, headers)
      end

      private

      def record(url, body, headers)
        @posts << { url: url, body: body, headers: headers }
        raise @error if @error

        FakeHttpResponse.new(status: @status, body: @body)
      end
    end
  end
end
