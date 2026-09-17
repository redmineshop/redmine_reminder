# frozen_string_literal: true

require_relative 'http'
require_relative 'project_webhooks'
require_relative 'webhook_url'

module RedmineReminder
  class ReminderService
    def self.process_reminders
      Rails.logger.info 'ReminderService: Starting reminder processing'

      project_ids = Reminder.active.distinct.pluck(:project_id)
      projects = Project.where(id: project_ids)
      Rails.logger.info "ReminderService: Found #{projects.count} projects with active reminders"

      reminders_sent = 0

      projects.each do |project|
        slack_url = safe_webhook(ProjectWebhooks.slack_url(project), 'Slack')
        slack_channel = ProjectWebhooks.slack_channel(project)
        gchat_url = safe_webhook(ProjectWebhooks.google_chat_url(project), 'Google Chat')

        next if slack_url.blank? && gchat_url.blank?

        all_reminders = project.reminders.active.includes(:created_by, :issue)
        Rails.logger.info "ReminderService: Project #{project.id} has #{all_reminders.count} active reminders total"

        reminders_to_send = []

        all_reminders.each do |reminder|
          user_timezone = get_user_timezone(reminder.created_by)
          current_time_in_user_tz = Time.current.in_time_zone(user_timezone)
          current_time_formatted = current_time_in_user_tz.strftime('%H:%M')
          reminder_time_in_user_tz = reminder.send_time.in_time_zone(user_timezone).strftime('%H:%M')

          Rails.logger.info "ReminderService: Checking reminder #{reminder.id} (tz: #{user_timezone})"
          Rails.logger.info "ReminderService: #{reminder_time_in_user_tz} vs #{current_time_formatted}"

          if reminder_time_in_user_tz == current_time_formatted && reminder.should_send_today?(user_timezone)
            reminders_to_send << reminder
            Rails.logger.info "ReminderService: Reminder #{reminder.id} scheduled to send"
          end
        end

        Rails.logger.info "ReminderService: Project #{project.id} has #{reminders_to_send.count} reminders to send"

        reminders_to_send.each do |reminder|
          delivered = false
          begin
            if slack_url && slack_channel
              send_reminder_to_slack(reminder, slack_url, slack_channel)
              delivered = true
            end
            if gchat_url
              send_reminder_to_google_chat(reminder, gchat_url)
              delivered = true
            end

            if delivered
              reminders_sent += 1
              Rails.logger.info "ReminderService: Successfully sent reminder #{reminder.id}"
              user_timezone = get_user_timezone(reminder.created_by)
              update_reminder_next_send_date(reminder, user_timezone)
            end
          rescue StandardError => e
            Rails.logger.error "ReminderService: Error sending reminder #{reminder.id}: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
          end
        end
      end

      Rails.logger.info "ReminderService: Completed processing. Sent #{reminders_sent} reminders"
      reminders_sent
    end

    def self.get_user_timezone(user)
      user_tz = user.preference&.time_zone

      if user_tz.present? && user_tz.strip != ''
        case user_tz.strip
        when 'Hanoi'
          'Asia/Ho_Chi_Minh'
        else
          if ActiveSupport::TimeZone[user_tz]
            user_tz
          else
            'Asia/Ho_Chi_Minh'
          end
        end
      else
        default_tz = Setting.default_users_time_zone

        if default_tz.present? && default_tz.strip != ''
          mapped_tz = case default_tz.strip
                      when 'Hanoi'
                        'Asia/Ho_Chi_Minh'
                      else
                        if ActiveSupport::TimeZone[default_tz]
                          default_tz
                        else
                          'Asia/Ho_Chi_Minh'
                        end
                      end
          Rails.logger.info "ReminderService: User has no timezone, using Redmine default: #{mapped_tz}"
          mapped_tz
        else
          fallback_tz = 'Asia/Ho_Chi_Minh'
          Rails.logger.info "ReminderService: User has no timezone and no Redmine default, using fallback: #{fallback_tz}"
          fallback_tz
        end
      end
    end
    private_class_method :get_user_timezone

    def self.safe_webhook(url, label)
      return nil if url.blank?
      return url if WebhookUrl.safe?(url)

      Rails.logger.warn "ReminderService: ignoring unsafe #{label} webhook host=#{WebhookUrl.host_for_log(url)}"
      nil
    end
    private_class_method :safe_webhook

    def self.send_reminder_to_slack(reminder, webhook_url, channel)
      message = format_reminder_message(reminder)
      username = Setting.plugin_redmine_reminder['username']
      icon = Setting.plugin_redmine_reminder['icon']

      params = {
        text: message,
        link_names: 1,
        channel: channel
      }
      params[:username] = username if username.present?

      if icon.present?
        if icon.start_with?(':')
          params[:icon_emoji] = icon
        else
          params[:icon_url] = icon
        end
      end

      client = Http.build_client
      client.post(webhook_url, payload: params.to_json)
    rescue StandardError => e
      Rails.logger.error "ReminderService: Failed to send to Slack host=#{WebhookUrl.host_for_log(webhook_url)}: #{e.message}"
      raise e
    end
    private_class_method :send_reminder_to_slack

    def self.send_reminder_to_google_chat(reminder, webhook_url)
      message = format_reminder_message(reminder)
      client = Http.build_client
      response = client.post(
        webhook_url,
        { 'text' => message }.to_json,
        { 'Content-Type' => 'application/json' }
      )

      unless response.status == 200
        raise "HTTP #{response.status}"
      end
    rescue StandardError => e
      Rails.logger.error "ReminderService: Failed to send to Google Chat host=#{WebhookUrl.host_for_log(webhook_url)}: #{e.message}"
      raise e
    end
    private_class_method :send_reminder_to_google_chat

    def self.format_reminder_message(reminder)
      content = reminder.content.to_s
                        .gsub(/\*\*(.*?)\*\*/, '*\1*')
                        .gsub(/_(.*?)_/, '_\1_')
                        .gsub(/~(.*?)~/, '~\1~')
                        .gsub(/\[(.*?)\]\((https?:\/\/[^\s)]+)\)/, '<\2|\1>')
                        .strip

      message_parts = []
      message_parts << I18n.t('gchat_notification_title', project_name: reminder.project.name)
      message_parts << ''
      message_parts << content

      if reminder.issue
        issue_url = generate_issue_url(reminder.issue)
        message_parts << ''
        message_parts << I18n.t(
          'gchat_notification_issue',
          issue_url: issue_url,
          issue_id: reminder.issue.id,
          issue_subject: reminder.issue.subject
        )
      end

      message_parts << ''
      message_parts << I18n.t('gchat_notification_time', date: reminder.formatted_send_date, time: reminder.formatted_send_time)

      if reminder.is_recurring?
        message_parts << I18n.t('gchat_notification_recurring', type: reminder.recurring_type_text)
        if reminder.recurring_type == 'custom'
          message_parts << I18n.t('gchat_notification_custom_days', days: reminder.custom_days_text)
        end
      end

      message_parts.join("\n")
    end
    private_class_method :format_reminder_message

    def self.generate_issue_url(issue)
      if Setting.host_name.present?
        protocol = Setting.protocol.present? ? Setting.protocol : 'http'
        "#{protocol}://#{Setting.host_name}/issues/#{issue.id}"
      else
        "/issues/#{issue.id}"
      end
    end
    private_class_method :generate_issue_url

    def self.update_reminder_next_send_date(reminder, timezone)
      return unless reminder.is_recurring?

      next_date = reminder.next_send_date(timezone)
      if next_date
        reminder.update_column(:send_date, next_date)
        Rails.logger.info "ReminderService: Updated reminder #{reminder.id} next send date to #{next_date}"
      end
    end
    private_class_method :update_reminder_next_send_date
  end
end
