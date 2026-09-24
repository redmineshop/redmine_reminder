# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ReminderListenerTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :issues,
           :trackers, :projects_trackers, :issue_statuses, :enumerations,
           :enabled_modules

  SLACK_URL = 'https://hooks.example.test/slack'
  GCHAT_URL = 'https://chat.example.test/space'

  def setup
    @project = Project.find(1)
    @issue = Issue.find(1)
    @previous_plugin_settings = Setting.plugin_redmine_reminder
    @previous_host = Setting.host_name
    @previous_protocol = Setting.protocol
    Setting.host_name = 'redmine.example.test'
    Setting.protocol = 'https'
    Setting.plugin_redmine_reminder = {
      'slack_url' => SLACK_URL,
      'channel' => '#ops',
      'username' => 'redmine',
      'icon' => ':bell:',
      'display_watchers' => 'no',
      'post_updates' => '0',
      'google_chat_webhook_url' => ''
    }
  end

  def teardown
    Setting.plugin_redmine_reminder = @previous_plugin_settings if @previous_plugin_settings
    Setting.host_name = @previous_host
    Setting.protocol = @previous_protocol
  end

  def test_speak_posts_slack_payload
    client = RedmineReminder::Test::FakeHttpClient.new

    with_stubbed_http_client(client) do
      RedmineReminder::Listener.instance.speak(
        'hello from redmine',
        '#ops',
        { text: 'note' },
        SLACK_URL
      )
    end

    assert_equal 1, client.posts.size
    assert_equal SLACK_URL, client.posts.first[:url]
    payload = JSON.parse(client.posts.first[:body][:payload])
    assert_equal 'hello from redmine', payload['text']
    assert_equal '#ops', payload['channel']
    assert_equal 'redmine', payload['username']
    assert_equal ':bell:', payload['icon_emoji']
  end

  def test_speak_posts_slack_and_project_google_chat
    attach_google_chat_webhook!(@project, GCHAT_URL)
    client = RedmineReminder::Test::FakeHttpClient.new

    with_stubbed_http_client(client) do
      RedmineReminder::Listener.instance.speak('hello', '#ops', nil, SLACK_URL, @project)
    end

    assert_equal [SLACK_URL, GCHAT_URL], client.posts.map { |post| post[:url] }
    gchat = JSON.parse(client.posts.last[:body])
    assert_equal 'hello', gchat['text']
  end

  def test_new_issue_hook_posts_slack
    client = RedmineReminder::Test::FakeHttpClient.new

    with_stubbed_http_client(client) do
      RedmineReminder::Listener.instance.redmine_reminder_issues_new_after_save(issue: @issue)
    end

    assert_equal 1, client.posts.size
    assert_equal SLACK_URL, client.posts.first[:url]
    payload = JSON.parse(client.posts.first[:body][:payload])
    assert_includes payload['text'], @issue.subject
    assert_includes payload['text'], @project.name
  end

  def test_new_issue_hook_skips_private_issue
    @issue.is_private = true
    client = RedmineReminder::Test::FakeHttpClient.new

    with_stubbed_http_client(client) do
      RedmineReminder::Listener.instance.redmine_reminder_issues_new_after_save(issue: @issue)
    end

    assert_empty client.posts
  end

  def test_new_issue_hook_skips_slack_when_channel_is_dash
    Setting.plugin_redmine_reminder = Setting.plugin_redmine_reminder.merge('channel' => '-')
    client = RedmineReminder::Test::FakeHttpClient.new

    with_stubbed_http_client(client) do
      RedmineReminder::Listener.instance.redmine_reminder_issues_new_after_save(issue: @issue)
    end

    assert_empty client.posts
  end

  def test_edit_hook_posts_slack_when_updates_enabled
    Setting.plugin_redmine_reminder = Setting.plugin_redmine_reminder.merge('post_updates' => '1')
    journal = Journal.new(user: User.find(2), notes: 'Updated the estimate')
    client = RedmineReminder::Test::FakeHttpClient.new

    with_stubbed_http_client(client) do
      RedmineReminder::Listener.instance.redmine_reminder_issues_edit_after_save(
        issue: @issue,
        journal: journal
      )
    end

    assert_equal 1, client.posts.size
    payload = JSON.parse(client.posts.first[:body][:payload])
    assert_includes payload['text'], @issue.subject
    assert_equal 'Updated the estimate', payload['attachments'].first['text']
  end

  def test_edit_hook_skips_private_notes
    Setting.plugin_redmine_reminder = Setting.plugin_redmine_reminder.merge(
      'post_updates' => '1',
      'google_chat_webhook_url' => GCHAT_URL
    )
    journal = Journal.new(user: User.find(2), notes: 'secret', private_notes: true)
    client = RedmineReminder::Test::FakeHttpClient.new

    with_stubbed_http_client(client) do
      RedmineReminder::Listener.instance.redmine_reminder_issues_edit_after_save(
        issue: @issue,
        journal: journal
      )
    end

    assert_empty client.posts
  end

  private

  def with_stubbed_http_client(client)
    with_stubbed_singleton(HTTPClient, :new, client) { yield }
  end

  def attach_google_chat_webhook!(project, url)
    field = ProjectCustomField.find_by(name: 'Google Chat Webhook') ||
            ProjectCustomField.create!(name: 'Google Chat Webhook', field_format: 'string')
    value = project.custom_values.find_or_initialize_by(custom_field: field)
    value.value = url
    value.save!
  end
end
