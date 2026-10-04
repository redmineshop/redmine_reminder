# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RedactionTest < ActiveSupport::TestCase
  def test_redacts_http_and_https_urls
    text = 'failed https://chat.example.test/spaces/SECRETTOKEN and http://hooks.example.test/T/SECRET'
    redacted = RedmineReminder::Redaction.redact(text)

    assert_equal 'failed [redacted-url] and [redacted-url]', redacted
    assert_not_includes redacted, 'SECRETTOKEN'
    assert_not_includes redacted, 'SECRET'
  end

  def test_leaves_text_without_urls_unchanged
    assert_equal 'HTTP 500: nope', RedmineReminder::Redaction.redact('HTTP 500: nope')
  end
end
