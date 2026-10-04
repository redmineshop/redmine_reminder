# frozen_string_literal: true

module RedmineReminder
  # Project custom fields that store Slack or Google Chat webhook URLs.
  # Redmine shows a custom field to every project member when `visible` is
  # true. These names are forced off that list so only administrators see them.
  module WebhookFields
    NAMES = ['Slack URL', 'Google Chat Webhook'].freeze

    def self.restrict!(field)
      return unless field&.persisted?
      return unless NAMES.include?(field.name)

      updates = {}
      updates[:visible] = false if field.visible?
      updates[:searchable] = false if field.has_attribute?(:searchable) && field.searchable?
      field.update_columns(updates) if updates.any?
      field.roles.clear if field.role_ids.any?
    end

    def self.restrict_existing!
      return unless defined?(ProjectCustomField) && ProjectCustomField.table_exists?

      ProjectCustomField.where(name: NAMES).find_each { |field| restrict!(field) }
    rescue StandardError
      # Plugin boot also runs before the database exists (asset compile, first migrate).
      nil
    end
  end

  module WebhookFieldGuard
    def self.included(base)
      base.before_validation :redmine_reminder_hide_webhook_url_field
    end

    private

    def redmine_reminder_hide_webhook_url_field
      return unless RedmineReminder::WebhookFields::NAMES.include?(name)

      self.visible = false
      self.searchable = false if has_attribute?(:searchable)
      self.role_ids = []
    end
  end
end
