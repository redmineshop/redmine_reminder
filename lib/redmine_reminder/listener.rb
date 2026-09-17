# frozen_string_literal: true

require_relative 'http'
require_relative 'project_webhooks'
require_relative 'webhook_url'

module RedmineReminder
  class Listener < Redmine::Hook::Listener
    def redmine_reminder_issues_new_after_save(context = {})
      issue = context[:issue]

      channel = channel_for_project issue.project
      url = url_for_project issue.project

      return unless (channel && url) || google_chat_webhook_url_for_project(issue.project)
      return if issue.is_private?

      msg = "[#{escape issue.project}] #{escape issue.author} created <#{object_url issue}|#{escape issue}>#{mentions issue.description}"

      attachment = {}
      attachment[:text] = escape issue.description if issue.description
      attachment[:fields] = [{
        title: I18n.t('field_status'),
        value: escape(issue.status.to_s),
        short: true
      }, {
        title: I18n.t('field_priority'),
        value: escape(issue.priority.to_s),
        short: true
      }, {
        title: I18n.t('field_assigned_to'),
        value: escape(issue.assigned_to.to_s),
        short: true
      }]

      if Setting.plugin_redmine_reminder['display_watchers'] == 'yes'
        attachment[:fields] << {
          title: I18n.t('field_watcher'),
          value: escape(issue.watcher_users.join(', ')),
          short: true
        }
      end

      speak msg, channel, attachment, url, issue.project
    end

    def redmine_reminder_issues_edit_after_save(context = {})
      issue = context[:issue]
      journal = context[:journal]

      channel = channel_for_project issue.project
      url = url_for_project issue.project

      return unless (channel && url && Setting.plugin_redmine_reminder['post_updates'] == '1') || google_chat_webhook_url_for_project(issue.project)
      return if issue.is_private?
      return if journal.private_notes?

      msg = "[#{escape issue.project}] #{escape journal.user.to_s} updated <#{object_url issue}|#{escape issue}>#{mentions journal.notes}"

      attachment = {}
      attachment[:text] = escape journal.notes if journal.notes
      attachment[:fields] = journal.details.map { |d| detail_to_field d }

      speak msg, channel, attachment, url, issue.project
    end

    def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context = {})
      issue = context[:issue]
      journal = issue.current_journal
      changeset = context[:changeset]

      channel = channel_for_project issue.project
      url = url_for_project issue.project

      return unless (channel && url && issue.save) || google_chat_webhook_url_for_project(issue.project)
      return if issue.is_private?

      msg = "[#{escape issue.project}] #{escape journal.user.to_s} updated <#{object_url issue}|#{escape issue}>"

      repository = changeset.repository

      if Setting.host_name.to_s =~ /\A(https?:\/\/)?(.+?)(:(\d+))?(\/.+)?\z/i
        host, port, prefix = $2, $4, $5
        revision_url = Rails.application.routes.url_for(
          controller: 'repositories',
          action: 'revision',
          id: repository.project,
          repository_id: repository.identifier_param,
          rev: changeset.revision,
          host: host,
          protocol: Setting.protocol,
          port: port,
          script_name: prefix
        )
      else
        revision_url = Rails.application.routes.url_for(
          controller: 'repositories',
          action: 'revision',
          id: repository.project,
          repository_id: repository.identifier_param,
          rev: changeset.revision,
          host: Setting.host_name,
          protocol: Setting.protocol
        )
      end

      attachment = {}
      attachment[:text] = ll(Setting.default_language, :text_status_changed_by_changeset, "<#{revision_url}|#{escape changeset.comments}>")
      attachment[:fields] = journal.details.map { |d| detail_to_field d }

      speak msg, channel, attachment, url, issue.project
    end

    def controller_wiki_edit_after_save(context = {})
      return unless Setting.plugin_redmine_reminder['post_wiki_updates'] == '1'

      project = context[:project]
      page = context[:page]

      user = page.content.author
      project_url = "<#{object_url project}|#{escape project}>"
      page_url = "<#{object_url page}|#{escape page.title}>"
      comment = "[#{project_url}] #{page_url} updated by *#{escape user}*"
      if page.content.version > 1
        comment << " [<#{object_url page}/diff?version=#{page.content.version}|difference>]"
      end

      channel = channel_for_project project
      url = url_for_project project

      return unless (channel && url) || google_chat_webhook_url_for_project(project)

      attachment = nil
      unless page.content.comments.empty?
        attachment = {}
        attachment[:text] = escape(page.content.comments).to_s
      end

      speak comment, channel, attachment, url, project
    end

    def speak(msg, channel, attachment = nil, url = nil, project = nil)
      slack_url = url || Setting.plugin_redmine_reminder['slack_url']
      if channel && slack_url && !slack_url.empty?
        if WebhookUrl.safe?(slack_url)
          username = Setting.plugin_redmine_reminder['username']
          icon = Setting.plugin_redmine_reminder['icon']

          params = {
            text: msg,
            link_names: 1
          }

          params[:username] = username if username
          params[:channel] = channel if channel
          params[:attachments] = [attachment] if attachment

          if icon && !icon.empty?
            if icon.start_with? ':'
              params[:icon_emoji] = icon
            else
              params[:icon_url] = icon
            end
          end

          begin
            client = Http.build_client
            client.post_async slack_url, payload: params.to_json
          rescue StandardError => e
            Rails.logger.warn("cannot connect to Slack webhook host=#{WebhookUrl.host_for_log(slack_url)}")
            Rails.logger.warn(e)
          end
        else
          Rails.logger.warn("ignoring unsafe Slack webhook host=#{WebhookUrl.host_for_log(slack_url)}")
        end
      end

      gchat_url = google_chat_webhook_url_for_project(project)
      if gchat_url && !gchat_url.empty?
        text = format_for_google_chat(msg, attachment)
        post_to_google_chat(text, gchat_url)
      end
    end

    private

    def post_to_google_chat(text, url)
      unless WebhookUrl.safe?(url)
        Rails.logger.warn("ignoring unsafe Google Chat webhook host=#{WebhookUrl.host_for_log(url)}")
        return
      end

      begin
        client = Http.build_client
        client.post_async url, { 'text' => text }.to_json, { 'Content-Type' => 'application/json' }
      rescue StandardError => e
        Rails.logger.warn("cannot connect to Google Chat webhook host=#{WebhookUrl.host_for_log(url)}")
        Rails.logger.warn(e)
      end
    end

    def format_for_google_chat(msg, attachment)
      text = msg.to_s.gsub('&lt;', '<').gsub('&gt;', '>').gsub('&amp;', '&')

      if attachment
        if attachment[:text]
          text << "\n" + attachment[:text].to_s.gsub('&lt;', '<').gsub('&gt;', '>').gsub('&amp;', '&')
        end
        if attachment[:fields]
          fields_text = attachment[:fields].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
          text << "\n" + fields_text
        end
      end

      text
    end

    def escape(msg)
      msg.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    def object_url(obj)
      if Setting.host_name.to_s =~ /\A(https?:\/\/)?(.+?)(:(\d+))?(\/.+)?\z/i
        host, port, prefix = $2, $4, $5
        Rails.application.routes.url_for(obj.event_url({
          host: host,
          protocol: Setting.protocol,
          port: port,
          script_name: prefix
        }))
      else
        Rails.application.routes.url_for(obj.event_url({
          host: Setting.host_name,
          protocol: Setting.protocol
        }))
      end
    end

    def url_for_project(proj)
      ProjectWebhooks.slack_url(proj)
    end

    def channel_for_project(proj)
      ProjectWebhooks.slack_channel(proj)
    end

    def google_chat_webhook_url_for_project(proj)
      ProjectWebhooks.google_chat_url(proj)
    end

    def detail_to_field(detail)
      case detail.property
      when 'cf'
        custom_field = detail.custom_field
        key = custom_field.name
        title = key
        raw = detail.value ? IssuesController.helpers.format_value(detail.value, custom_field) : ''
        value = escape(raw.to_s)
      when 'attachment'
        key = 'attachment'
        title = I18n.t :label_attachment
        value = escape detail.value.to_s
      else
        key = detail.prop_key.to_s.sub('_id', '')
        if key == 'parent'
          title = I18n.t "field_#{key}_issue"
        else
          title = I18n.t "field_#{key}"
        end
        value = escape detail.value.to_s
      end

      short = true

      case key
      when 'title', 'subject', 'description'
        short = false
      when 'tracker'
        tracker = Tracker.find(detail.value) rescue nil
        value = escape tracker.to_s
      when 'project'
        project = Project.find(detail.value) rescue nil
        value = escape project.to_s
      when 'status'
        status = IssueStatus.find(detail.value) rescue nil
        value = escape status.to_s
      when 'priority'
        priority = IssuePriority.find(detail.value) rescue nil
        value = escape priority.to_s
      when 'category'
        category = IssueCategory.find(detail.value) rescue nil
        value = escape category.to_s
      when 'assigned_to'
        user = User.find(detail.value) rescue nil
        value = escape user.to_s
      when 'fixed_version'
        version = Version.find(detail.value) rescue nil
        value = escape version.to_s
      when 'attachment'
        attachment = Attachment.find(detail.prop_key) rescue nil
        value = "<#{object_url attachment}|#{escape attachment.filename}>" if attachment
      when 'parent'
        issue = Issue.find(detail.value) rescue nil
        value = "<#{object_url issue}|#{escape issue}>" if issue
      end

      value = '-' if value.empty?

      result = { title: title, value: value }
      result[:short] = true if short
      result
    end

    def mentions(text)
      return nil if text.nil?

      names = extract_usernames text
      names.present? ? "\nTo: " + names.join(', ') : nil
    end

    def extract_usernames(text = '')
      text = '' if text.nil?

      # Slack usernames may only contain lowercase letters, numbers,
      # dashes and underscores and must start with a letter or number.
      text.scan(/@[a-z0-9][a-z0-9_\-\.]*/).uniq
    end
  end
end
