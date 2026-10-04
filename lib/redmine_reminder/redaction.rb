# frozen_string_literal: true

module RedmineReminder
  module Redaction
    URL = %r{https?://[^\s<>'"\\]+}i

    def self.redact(text)
      text.to_s.gsub(URL, '[redacted-url]')
    end
  end
end
