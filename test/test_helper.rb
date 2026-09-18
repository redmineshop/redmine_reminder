# frozen_string_literal: true

require File.expand_path('../../../test/test_helper', __dir__)

unless Project.included_modules.include?(RedmineReminder::ProjectPatch)
  Project.include RedmineReminder::ProjectPatch
end

unless Issue.included_modules.include?(RedmineReminder::IssuePatch)
  Issue.include RedmineReminder::IssuePatch
end
