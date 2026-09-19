# frozen_string_literal: true

require 'redmine'

require_relative 'lib/redmine_reminder/version'
require File.expand_path('../lib/redmine_reminder/listener', __FILE__)
require File.expand_path('../lib/redmine_reminder/reminder_service', __FILE__)

Redmine::Plugin.register :redmine_reminder do
  name 'Redmine Reminder'
  author 'RedmineShop (based on sciyoshi/redmine-slack)'
  url 'https://redmineshop.com/products/redmine-reminder'
  author_url 'https://redmineshop.com'
  description 'Schedule recurring reminders for Redmine issues and projects — send notifications to Slack or Google Chat webhooks.'
  version RedmineReminder::VERSION

  requires_redmine version_or_higher: '5.0'

	settings \
		:default => {
			'callback_url' => 'http://slack.com/callback/',
			'channel' => nil,
			'icon' => 'https://raw.github.com/sciyoshi/redmine-slack/gh-pages/icon.png',
			'username' => 'redmine',
			'display_watchers' => 'no',
			'google_chat_webhook_url' => ''
		},
		:partial => 'settings/reminder_settings'

	# Permissions for reminder functionality
	project_module :reminders do
		permission :view_reminders, { :reminders => [:index, :show] }
		permission :manage_reminders, { :reminders => [:new, :create, :edit, :update, :destroy] }
	end

	# Add menu item to project menu
	menu :project_menu, :reminders, { :controller => 'reminders', :action => 'index' }, 
		 :caption => 'Reminder', :after => :activity, :param => :project_id
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
	((Rails.version > "5")? ActiveSupport::Reloader : ActionDispatch::Callbacks).to_prepare do
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
