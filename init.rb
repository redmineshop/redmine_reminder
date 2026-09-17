# frozen_string_literal: true

require 'redmine'

require_relative 'lib/redmine_reminder/version'
require_relative 'lib/redmine_reminder/webhook_url'
require_relative 'lib/redmine_reminder/http'
require_relative 'lib/redmine_reminder/project_webhooks'
require_relative 'lib/redmine_reminder/issue_patch'
require_relative 'lib/redmine_reminder/project_patch'
require_relative 'lib/redmine_reminder/listener'
require_relative 'lib/redmine_reminder/reminder_service'

Redmine::Plugin.register :redmine_reminder do
  name 'Redmine Reminder'
  author 'RedmineShop (based on sciyoshi/redmine-slack)'
  url 'https://github.com/redmineshop/redmine_reminder'
  author_url 'https://github.com/redmineshop'
  description 'Community (free, MIT) plugin: schedule recurring reminders and send Slack or Google Chat notifications.'
  version RedmineReminder::VERSION

  requires_redmine version_or_higher: '5.0'

  settings \
    default: {
      'slack_url' => '',
      'channel' => nil,
      'icon' => 'https://raw.github.com/sciyoshi/redmine-slack/gh-pages/icon.png',
      'username' => 'redmine',
      'display_watchers' => 'no',
      'google_chat_webhook_url' => '',
      'post_updates' => '0',
      'post_wiki_updates' => '0'
    },
    partial: 'settings/reminder_settings'

  project_module :reminders do
    permission :view_reminders, { reminders: [:index, :show] }
    permission :manage_reminders, { reminders: [:new, :create, :edit, :update, :destroy] }
  end

  menu :project_menu, :reminders, { controller: 'reminders', action: 'index' },
       caption: :label_reminder, after: :activity, param: :project_id
end

if Rails.version > '6.0' && Rails.autoloaders.zeitwerk_enabled?
  Rails.application.config.after_initialize do
    unless Issue.included_modules.include? RedmineReminder::IssuePatch
      Issue.send(:include, RedmineReminder::IssuePatch)
    end
    unless Project.included_modules.include? RedmineReminder::ProjectPatch
      Project.send(:include, RedmineReminder::ProjectPatch)
    end
  end
else
  ((Rails.version > '5') ? ActiveSupport::Reloader : ActionDispatch::Callbacks).to_prepare do
    require_dependency 'issue'
    require_dependency 'project'
    unless Issue.included_modules.include? RedmineReminder::IssuePatch
      Issue.send(:include, RedmineReminder::IssuePatch)
    end
    unless Project.included_modules.include? RedmineReminder::ProjectPatch
      Project.send(:include, RedmineReminder::ProjectPatch)
    end
  end
end
