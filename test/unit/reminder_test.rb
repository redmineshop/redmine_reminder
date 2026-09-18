# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ReminderTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :issues,
           :trackers, :projects_trackers, :issue_statuses, :enumerations,
           :enabled_modules

  UTC = 'UTC'

  def setup
    @project = Project.find(1)
    @author = User.find(2)
  end

  def test_requires_content
    reminder = build_reminder(content: '')
    assert_not reminder.valid?
    assert reminder.errors[:content].present?
  end

  def test_requires_send_date
    reminder = build_reminder(send_date: nil)
    assert_not reminder.valid?
    assert reminder.errors[:send_date].present?
  end

  def test_requires_send_time
    reminder = build_reminder(send_time: nil)
    assert_not reminder.valid?
    assert reminder.errors[:send_time].present?
  end

  def test_rejects_unknown_recurring_type
    reminder = build_reminder(is_recurring: true, recurring_type: 'monthly')
    assert_not reminder.valid?
    assert reminder.errors[:recurring_type].present?
  end

  def test_allows_blank_recurring_type_for_one_shot
    reminder = build_reminder(is_recurring: false, recurring_type: '')
    assert reminder.valid?
  end

  def test_custom_recurring_requires_custom_days
    reminder = build_reminder(is_recurring: true, recurring_type: 'custom', custom_days: '')
    assert_not reminder.valid?
    assert reminder.errors[:custom_days].present?
  end

  def test_custom_recurring_rejects_invalid_days
    reminder = build_reminder(is_recurring: true, recurring_type: 'custom', custom_days: '1,9')
    assert_not reminder.valid?
    assert reminder.errors[:custom_days].present?
  end

  def test_custom_recurring_accepts_weekday_codes
    reminder = build_reminder(is_recurring: true, recurring_type: 'custom', custom_days: '1,3,5')
    assert reminder.valid?
  end

  def test_weekday_options_use_ruby_wday_codes
    assert_equal [1, 2, 3, 4, 5, 6, 0], Reminder.weekday_options.map(&:last)
  end

  def test_recurring_type_options
    assert_equal %w[daily weekdays weekly custom], Reminder.recurring_type_options.map(&:last)
  end

  def test_one_shot_sends_only_on_send_date
    travel_to Time.utc(2026, 9, 18, 10, 0, 0) do
      reminder = build_reminder(send_date: Date.new(2026, 9, 18), is_recurring: false)
      assert reminder.should_send_today?(UTC)

      reminder.send_date = Date.new(2026, 9, 17)
      assert_not reminder.should_send_today?(UTC)

      reminder.send_date = Date.new(2026, 9, 19)
      assert_not reminder.should_send_today?(UTC)
    end
  end

  def test_inactive_never_sends
    travel_to Time.utc(2026, 9, 18, 10, 0, 0) do
      reminder = build_reminder(send_date: Date.new(2026, 9, 18), active: false)
      assert_not reminder.should_send_today?(UTC)
    end
  end

  def test_daily_recurring_sends_on_or_after_start
    travel_to Time.utc(2026, 9, 18, 10, 0, 0) do
      reminder = build_reminder(
        send_date: Date.new(2026, 9, 10),
        is_recurring: true,
        recurring_type: 'daily'
      )
      assert reminder.should_send_today?(UTC)
    end
  end

  def test_weekdays_recurring_skips_weekend
    reminder = build_reminder(
      send_date: Date.new(2026, 9, 14),
      is_recurring: true,
      recurring_type: 'weekdays'
    )

    travel_to Time.utc(2026, 9, 18, 10, 0, 0) do
      assert reminder.should_send_today?(UTC)
    end

    travel_to Time.utc(2026, 9, 19, 10, 0, 0) do
      assert_not reminder.should_send_today?(UTC)
    end
  end

  def test_weekly_recurring_matches_start_weekday
    reminder = build_reminder(
      send_date: Date.new(2026, 9, 18),
      is_recurring: true,
      recurring_type: 'weekly'
    )

    travel_to Time.utc(2026, 9, 25, 10, 0, 0) do
      assert reminder.should_send_today?(UTC)
    end

    travel_to Time.utc(2026, 9, 24, 10, 0, 0) do
      assert_not reminder.should_send_today?(UTC)
    end
  end

  def test_custom_recurring_matches_listed_wdays
    reminder = build_reminder(
      send_date: Date.new(2026, 9, 14),
      is_recurring: true,
      recurring_type: 'custom',
      custom_days: '5'
    )

    travel_to Time.utc(2026, 9, 18, 10, 0, 0) do
      assert reminder.should_send_today?(UTC)
    end

    travel_to Time.utc(2026, 9, 17, 10, 0, 0) do
      assert_not reminder.should_send_today?(UTC)
    end
  end

  def test_next_send_date_daily
    travel_to Time.utc(2026, 9, 18, 10, 0, 0) do
      reminder = build_reminder(is_recurring: true, recurring_type: 'daily')
      assert_equal Date.new(2026, 9, 19), reminder.next_send_date(UTC)
    end
  end

  def test_next_send_date_weekdays_skips_weekend
    travel_to Time.utc(2026, 9, 18, 10, 0, 0) do
      reminder = build_reminder(is_recurring: true, recurring_type: 'weekdays')
      assert_equal Date.new(2026, 9, 21), reminder.next_send_date(UTC)
    end
  end

  def test_next_send_date_weekly
    travel_to Time.utc(2026, 9, 18, 10, 0, 0) do
      reminder = build_reminder(is_recurring: true, recurring_type: 'weekly')
      assert_equal Date.new(2026, 9, 25), reminder.next_send_date(UTC)
    end
  end

  def test_next_send_date_custom_wraps_to_next_week
    travel_to Time.utc(2026, 9, 18, 10, 0, 0) do
      reminder = build_reminder(
        is_recurring: true,
        recurring_type: 'custom',
        custom_days: '1,3'
      )
      assert_equal Date.new(2026, 9, 21), reminder.next_send_date(UTC)
    end
  end

  def test_next_send_date_nil_when_not_recurring
    reminder = build_reminder(is_recurring: false)
    assert_nil reminder.next_send_date(UTC)
  end

  def test_formatted_send_date
    reminder = build_reminder(send_date: Date.new(2026, 9, 18))
    assert_equal '18/09/2026', reminder.formatted_send_date
  end

  private

  def build_reminder(attrs = {})
    Reminder.new(
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
end
