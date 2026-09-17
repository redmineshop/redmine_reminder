# frozen_string_literal: true

module RedmineReminder
  # Resolves Slack / Google Chat webhook settings from project custom fields,
  # parent projects, then plugin defaults.
  module ProjectWebhooks
    SLACK_URL_FIELD = 'Slack URL'
    SLACK_CHANNEL_FIELD = 'Slack Channel'
    GOOGLE_CHAT_FIELD = 'Google Chat Webhook'

    module_function

    def slack_url(project)
      first_present(
        custom_field_value(project, SLACK_URL_FIELD),
        project && slack_url(project.parent),
        plugin_setting('slack_url')
      )
    end

    def slack_channel(project)
      val = first_present(
        custom_field_value(project, SLACK_CHANNEL_FIELD),
        project && slack_channel(project.parent),
        plugin_setting('channel')
      )
      # Channel name '-' is reserved for NOT notifying
      return nil if val.to_s == '-'

      val
    end

    def google_chat_url(project)
      first_present(
        custom_field_value(project, GOOGLE_CHAT_FIELD),
        project && google_chat_url(project.parent),
        plugin_setting('google_chat_webhook_url')
      )
    end

    def custom_field_value(project, field_name)
      return nil if project.blank?

      cf = ProjectCustomField.find_by_name(field_name)
      return nil unless cf

      project.custom_value_for(cf)&.value
    rescue StandardError
      nil
    end

    def plugin_setting(key)
      Setting.plugin_redmine_reminder[key]
    rescue StandardError
      nil
    end

    def first_present(*values)
      values.find { |value| value.respond_to?(:present?) ? value.present? : !value.nil? && value != '' }
    end
  end
end
