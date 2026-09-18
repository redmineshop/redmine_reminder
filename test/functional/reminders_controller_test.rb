# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RemindersControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :roles, :members, :member_roles, :issues,
           :trackers, :projects_trackers, :issue_statuses, :enumerations,
           :enabled_modules

  def setup
    @project = Project.find(1)
    EnabledModule.create!(project: @project, name: 'reminders') unless @project.module_enabled?(:reminders)

    Role.find(1).add_permission!(:view_reminders, :manage_reminders)
    Role.find(2).remove_permission!(:view_reminders) if Role.find(2).has_permission?(:view_reminders)
    Role.find(2).remove_permission!(:manage_reminders) if Role.find(2).has_permission?(:manage_reminders)
  end

  def test_index_success_for_member_with_permission
    reminder = create_reminder!(content: 'Visible standup')
    @request.session[:user_id] = 2

    get :index, params: { project_id: @project.id }
    assert_response :success
    assert_select 'h2', /Reminders/
    assert_select 'tr.reminder td.content', text: /Visible standup/
    assert_select 'td.id a[href=?]', project_reminder_path(@project, reminder)
  end

  def test_index_forbidden_without_permission
    @request.session[:user_id] = 3
    get :index, params: { project_id: @project.id }
    assert_response :forbidden
  end

  def test_index_requires_login
    @request.session[:user_id] = nil
    get :index, params: { project_id: @project.id }
    assert_response :redirect
  end

  def test_show_success_for_member_with_permission
    reminder = create_reminder!(content: 'Detail standup')
    @request.session[:user_id] = 2

    get :show, params: { project_id: @project.id, id: reminder.id }
    assert_response :success
    assert_select 'h2', /Reminder Details/
    assert_select '.wiki', text: /Detail standup/
    assert_select '.status-active'
  end

  def test_show_forbidden_without_permission
    reminder = create_reminder!
    @request.session[:user_id] = 3
    get :show, params: { project_id: @project.id, id: reminder.id }
    assert_response :forbidden
  end

  def test_show_missing_reminder_is_not_found
    @request.session[:user_id] = 2
    get :show, params: { project_id: @project.id, id: 9_999_999 }
    assert_response :not_found
  end

  def test_create_success_for_member_with_permission
    @request.session[:user_id] = 2
    assert_difference 'Reminder.count', 1 do
      post :create, params: {
        project_id: @project.id,
        reminder: {
          content: 'Harness standup ping',
          send_date: Date.new(2026, 9, 19).to_s,
          send_time: '09:30',
          issue_id: 1,
          active: '1'
        }
      }
    end
    assert_redirected_to project_reminders_path(@project)
    reminder = Reminder.order(:id).last
    assert_equal 'Harness standup ping', reminder.content
    assert_equal @project.id, reminder.project_id
    assert_equal 2, reminder.created_by_id
    assert_equal 1, reminder.issue_id
    assert reminder.active?
  end

  def test_create_invalid_redisplays_form
    @request.session[:user_id] = 2
    assert_no_difference 'Reminder.count' do
      post :create, params: {
        project_id: @project.id,
        reminder: {
          content: '',
          send_date: Date.new(2026, 9, 19).to_s,
          send_time: '09:30'
        }
      }
    end
    assert_response :success
    assert_select 'textarea[name=?]', 'reminder[content]'
  end

  def test_create_forbidden_without_permission
    @request.session[:user_id] = 3
    assert_no_difference 'Reminder.count' do
      post :create, params: {
        project_id: @project.id,
        reminder: {
          content: 'Nope',
          send_date: Date.new(2026, 9, 19).to_s,
          send_time: '09:30'
        }
      }
    end
    assert_response :forbidden
  end

  private

  def create_reminder!(attrs = {})
    Reminder.create!(
      {
        project: @project,
        created_by: User.find(2),
        content: 'Standup ping',
        send_date: Date.new(2026, 9, 18),
        send_time: Time.utc(2000, 1, 1, 9, 30, 0),
        is_recurring: false,
        active: true
      }.merge(attrs)
    )
  end
end
