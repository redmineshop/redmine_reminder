# frozen_string_literal: true

# Standalone checks — no Redmine/Rails required. Run from CI with:
#   ruby test/webhook_url_test.rb

require_relative '../lib/redmine_reminder/webhook_url'

failures = 0

def check(name, condition)
  if condition
    puts "ok  - #{name}"
    true
  else
    puts "FAIL - #{name}"
    false
  end
end

public_resolver = ->(_host) { ['8.8.8.8'] }
loopback_resolver = ->(_host) { ['127.0.0.1'] }
empty_resolver = ->(_host) { [] }

cases = [
  ['rejects nil', !RedmineReminder::WebhookUrl.safe?(nil)],
  ['rejects empty', !RedmineReminder::WebhookUrl.safe?('')],
  ['rejects http', !RedmineReminder::WebhookUrl.safe?('http://hooks.slack.com/services/x', resolver: public_resolver)],
  ['rejects userinfo', !RedmineReminder::WebhookUrl.safe?('https://user:pass@hooks.slack.com/x', resolver: public_resolver)],
  ['rejects localhost host', !RedmineReminder::WebhookUrl.safe?('https://localhost/hook')],
  ['rejects .internal host', !RedmineReminder::WebhookUrl.safe?('https://foo.internal/hook', resolver: public_resolver)],
  ['rejects loopback literal', !RedmineReminder::WebhookUrl.safe?('https://127.0.0.1/hook')],
  ['rejects metadata IP', !RedmineReminder::WebhookUrl.safe?('https://169.254.169.254/latest/meta-data')],
  ['rejects private IPv4', !RedmineReminder::WebhookUrl.safe?('https://192.168.1.10/hook')],
  ['rejects RFC1918 10/8', !RedmineReminder::WebhookUrl.safe?('https://10.0.0.5/hook')],
  ['rejects IPv6 loopback', !RedmineReminder::WebhookUrl.safe?('https://[::1]/hook')],
  ['rejects resolved loopback', !RedmineReminder::WebhookUrl.safe?('https://hooks.slack.com/services/x', resolver: loopback_resolver)],
  ['rejects failed DNS', !RedmineReminder::WebhookUrl.safe?('https://hooks.slack.com/services/x', resolver: empty_resolver)],
  ['allows public Slack-shaped URL', RedmineReminder::WebhookUrl.safe?('https://hooks.slack.com/services/T00/B00/xxx', resolver: public_resolver)],
  ['allows public Google Chat-shaped URL', RedmineReminder::WebhookUrl.safe?('https://chat.googleapis.com/v1/spaces/AAA/messages?key=x', resolver: public_resolver)],
  ['host_for_log hides path', RedmineReminder::WebhookUrl.host_for_log('https://hooks.slack.com/services/secret') == 'hooks.slack.com']
]

cases.each do |name, ok|
  failures += 1 unless check(name, ok)
end

puts
if failures.zero?
  puts "All #{cases.size} checks passed"
  exit 0
else
  puts "#{failures} of #{cases.size} checks failed"
  exit 1
end
