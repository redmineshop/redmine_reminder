# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)
require 'rake'

class ReminderDispatchTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :issues,
           :trackers, :projects_trackers, :issue_statuses, :enumerations,
           :enabled_modules

  WEBHOOK_URL = 'https://chat.example.test/webhook'
  RAKE_FILE = File.expand_path('../../lib/tasks/reminders.rake', __dir__)

  def setup
    @project = Project.find(1)
    @author = User.find(2)
    @author.pref.update!(time_zone: 'UTC')
    @previous_host = Setting.host_name
    Setting.host_name = 'redmine.example.test'
  end

  def teardown
    Setting.host_name = @previous_host
  end

  def test_process_reminders_posts_stubbed_google_chat_and_advances_recurring_date
    reminder = nil
    sent = nil
    client = RedmineReminder::Test::FakeHttpClient.new

    travel_to Time.utc(2026, 9, 18, 9, 30, 0) do
      reminder = create_reminder!(
        content: '**Standup** in the kitchen',
        send_date: Date.new(2026, 9, 18),
        send_time: Time.current,
        is_recurring: true,
        recurring_type: 'daily',
        issue_id: 1
      )
      attach_google_chat_webhook!(@project, WEBHOOK_URL)

      with_stubbed_http_client(client) do
        sent = RedmineReminder::ReminderService.process_reminders
      end
    end

    assert_equal 1, sent
    assert_equal 1, client.posts.size
    assert_equal WEBHOOK_URL, client.posts.first[:url]
    assert_equal 'application/json', client.posts.first[:headers]['Content-Type']

    body = JSON.parse(client.posts.first[:body])
    assert_includes body['text'], '*Standup*'
    assert_includes body['text'], @project.name
    assert_includes body['text'], '/issues/1'
    assert_not_includes body['text'], '**Standup**'
    assert_equal Date.new(2026, 9, 19), reminder.reload.send_date
  end

  def test_process_reminders_leaves_one_shot_date_unchanged
    reminder = nil
    client = RedmineReminder::Test::FakeHttpClient.new

    travel_to Time.utc(2026, 9, 18, 9, 30, 0) do
      reminder = create_reminder!(
        content: 'One shot',
        send_date: Date.new(2026, 9, 18),
        send_time: Time.current,
        is_recurring: false
      )
      attach_google_chat_webhook!(@project, WEBHOOK_URL)

      with_stubbed_http_client(client) do
        assert_equal 1, RedmineReminder::ReminderService.process_reminders
      end
    end

    assert_equal Date.new(2026, 9, 18), reminder.reload.send_date
  end

  def test_process_reminders_skips_when_minute_does_not_match
    client = RedmineReminder::Test::FakeHttpClient.new

    travel_to Time.utc(2026, 9, 18, 9, 30, 0) do
      create_reminder!(
        content: 'Wrong minute',
        send_date: Date.new(2026, 9, 18),
        send_time: Time.utc(2000, 1, 1, 8, 0, 0)
      )
      attach_google_chat_webhook!(@project, WEBHOOK_URL)

      with_stubbed_http_client(client) do
        assert_equal 0, RedmineReminder::ReminderService.process_reminders
      end
    end

    assert_empty client.posts
  end

  def test_process_reminders_skips_inactive_reminder
    client = RedmineReminder::Test::FakeHttpClient.new

    travel_to Time.utc(2026, 9, 18, 9, 30, 0) do
      create_reminder!(
        content: 'Inactive',
        send_date: Date.new(2026, 9, 18),
        send_time: Time.current,
        active: false
      )
      attach_google_chat_webhook!(@project, WEBHOOK_URL)

      with_stubbed_http_client(client) do
        assert_equal 0, RedmineReminder::ReminderService.process_reminders
      end
    end

    assert_empty client.posts
  end

  def test_process_reminders_skips_blank_webhook
    client = RedmineReminder::Test::FakeHttpClient.new

    travel_to Time.utc(2026, 9, 18, 9, 30, 0) do
      create_reminder!(
        content: 'No destination',
        send_date: Date.new(2026, 9, 18),
        send_time: Time.current
      )
      attach_google_chat_webhook!(@project, '')

      with_stubbed_http_client(client) do
        assert_equal 0, RedmineReminder::ReminderService.process_reminders
      end
    end

    assert_empty client.posts
  end

  def test_process_reminders_swallows_non_success_webhook
    reminder = nil
    client = RedmineReminder::Test::FakeHttpClient.new(status: 500, body: 'nope')

    travel_to Time.utc(2026, 9, 18, 9, 30, 0) do
      reminder = create_reminder!(
        content: 'Will fail',
        send_date: Date.new(2026, 9, 18),
        send_time: Time.current,
        is_recurring: true,
        recurring_type: 'daily'
      )
      attach_google_chat_webhook!(@project, WEBHOOK_URL)

      sent = nil
      with_stubbed_http_client(client) do
        sent = RedmineReminder::ReminderService.process_reminders
      end
      assert_equal 0, sent
    end

    assert_equal 1, client.posts.size
    assert_equal Date.new(2026, 9, 18), reminder.reload.send_date
  end

  def test_rake_send_reminders_dispatches_through_service
    load_reminder_rake_tasks!
    client = RedmineReminder::Test::FakeHttpClient.new
    output = +''

    travel_to Time.utc(2026, 9, 18, 9, 30, 0) do
      create_reminder!(
        content: 'Cron ping',
        send_date: Date.new(2026, 9, 18),
        send_time: Time.current
      )
      attach_google_chat_webhook!(@project, WEBHOOK_URL)

      with_stubbed_http_client(client) do
        output = capture_stdout { invoke_reminder_task('redmine_reminder:send_reminders') }
      end
    end

    assert_match(/Sent 1 reminders/, output)
    assert_equal WEBHOOK_URL, client.posts.first[:url]
  end

  def test_rake_alias_redmine_reminders_send_runs_same_dispatch
    load_reminder_rake_tasks!
    client = RedmineReminder::Test::FakeHttpClient.new
    output = +''

    travel_to Time.utc(2026, 9, 18, 9, 30, 0) do
      create_reminder!(
        content: 'Alias ping',
        send_date: Date.new(2026, 9, 18),
        send_time: Time.current
      )
      attach_google_chat_webhook!(@project, WEBHOOK_URL)

      with_stubbed_http_client(client) do
        output = capture_stdout { invoke_reminder_task('redmine:reminders:send') }
      end
    end

    assert_match(/Sent 1 reminders/, output)
    assert_equal 1, client.posts.size
  end

  def test_rake_send_reminders_exits_when_dispatch_raises
    load_reminder_rake_tasks!
    error = nil

    with_stubbed_singleton(RedmineReminder::ReminderService, :process_reminders, -> { raise 'dispatch failed' }) do
      error = assert_raises(SystemExit) do
        capture_stdout { invoke_reminder_task('redmine_reminder:send_reminders') }
      end
    end

    assert_equal 1, error.status
  end

  private

  def create_reminder!(attrs = {})
    Reminder.create!(
      {
        project: @project,
        created_by: @author,
        content: 'Standup ping',
        send_date: Date.new(2026, 9, 18),
        send_time: Time.utc(2000, 1, 1, 9, 30, 0),
        is_recurring: false,
        active: true
      }.merge(attrs)
    )
  end

  def attach_google_chat_webhook!(project, url)
    field = ProjectCustomField.find_by(name: 'Google Chat Webhook') ||
            ProjectCustomField.create!(name: 'Google Chat Webhook', field_format: 'string')
    value = project.custom_values.find_or_initialize_by(custom_field: field)
    value.value = url
    value.save!
    field
  end

  def with_stubbed_http_client(client)
    with_stubbed_singleton(HTTPClient, :new, client) { yield }
  end

  def load_reminder_rake_tasks!
    return if Rake::Task.task_defined?('redmine_reminder:send_reminders') &&
              Rake::Task.task_defined?('redmine:reminders:send')

    load RAKE_FILE
  end

  def invoke_reminder_task(name)
    # The test process has already booted Rails. Drop the :environment
    # prerequisite so Rake does not look up a task this runner never defined.
    [name, 'redmine_reminder:send_reminders'].uniq.each do |task_name|
      next unless Rake::Task.task_defined?(task_name)

      task = Rake::Task[task_name]
      task.prerequisites.clear
      task.reenable
    end
    Rake::Task[name].invoke
  end
end
