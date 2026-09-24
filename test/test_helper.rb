# frozen_string_literal: true

require File.expand_path('../../../test/test_helper', __dir__)

unless Project.included_modules.include?(RedmineReminder::ProjectPatch)
  Project.include RedmineReminder::ProjectPatch
end

unless Issue.included_modules.include?(RedmineReminder::IssuePatch)
  Issue.include RedmineReminder::IssuePatch
end

require 'stringio'
require File.expand_path('support/fake_http_client', __dir__)

# Minitest's Object#stub is not available on the demo image's Ruby.
def with_stubbed_singleton(object, method_name, replacement)
  singleton = object.singleton_class
  backup = :"__redmine_reminder_unstubbed_#{method_name}"
  singleton.send(:alias_method, backup, method_name)
  singleton.send(:define_method, method_name) do |*args, **kwargs, &block|
    if replacement.respond_to?(:call)
      replacement.call(*args, **kwargs, &block)
    else
      replacement
    end
  end
  yield
ensure
  if singleton && (singleton.method_defined?(backup) || singleton.private_method_defined?(backup))
    singleton.send(:alias_method, method_name, backup)
    singleton.send(:remove_method, backup)
  end
end

def capture_stdout
  original = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = original
end
