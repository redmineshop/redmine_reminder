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

  def test_edit_success_for_member_with_permission
    reminder = create_reminder!(content: 'Edit me')
    @request.session[:user_id] = 2

    get :edit, params: { project_id: @project.id, id: reminder.id }
    assert_response :success
    assert_select 'h2', /Edit reminder/
    assert_select 'textarea[name=?]', 'reminder[content]', text: /Edit me/
  end

  def test_edit_forbidden_without_permission
    reminder = create_reminder!
    @request.session[:user_id] = 3
    get :edit, params: { project_id: @project.id, id: reminder.id }
    assert_response :forbidden
  end

  def test_edit_requires_login
    reminder = create_reminder!
    @request.session[:user_id] = nil
    get :edit, params: { project_id: @project.id, id: reminder.id }
    assert_response :redirect
  end

  def test_edit_missing_reminder_is_not_found
    @request.session[:user_id] = 2
    get :edit, params: { project_id: @project.id, id: 9_999_999 }
    assert_response :not_found
  end

  def test_update_success_for_member_with_permission
    reminder = create_reminder!(content: 'Before update')
    User.find(2).pref.update!(time_zone: 'UTC')
    @request.session[:user_id] = 2

    put :update, params: {
      project_id: @project.id,
      id: reminder.id,
      reminder: {
        content: 'Updated standup',
        send_date: Date.new(2026, 9, 20).to_s,
        send_time: '10:15',
        active: '0',
        is_recurring: '1',
        recurring_type: 'weekly',
        issue_id: 1
      }
    }
    assert_redirected_to project_reminders_path(@project)
    assert_equal I18n.t(:notice_reminder_updated_successfully), flash[:notice]

    reminder.reload
    assert_equal 'Updated standup', reminder.content
    assert_equal Date.new(2026, 9, 20), reminder.send_date
    assert_equal '10:15', reminder.formatted_send_time('UTC')
    assert_not reminder.active?
    assert reminder.is_recurring?
    assert_equal 'weekly', reminder.recurring_type
    assert_equal 1, reminder.issue_id
  end

  def test_update_invalid_redisplays_edit
    reminder = create_reminder!(content: 'Keep me')
    @request.session[:user_id] = 2

    put :update, params: {
      project_id: @project.id,
      id: reminder.id,
      reminder: {
        content: '',
        send_date: Date.new(2026, 9, 20).to_s,
        send_time: '10:15'
      }
    }
    assert_response :success
    assert_select 'h2', /Edit reminder/
    assert_equal 'Keep me', reminder.reload.content
  end

  def test_update_forbidden_without_permission
    reminder = create_reminder!(content: 'Locked')
    @request.session[:user_id] = 3

    put :update, params: {
      project_id: @project.id,
      id: reminder.id,
      reminder: {
        content: 'Hijack',
        send_date: Date.new(2026, 9, 20).to_s,
        send_time: '10:15'
      }
    }
    assert_response :forbidden
    assert_equal 'Locked', reminder.reload.content
  end

  def test_update_other_projects_reminder_is_not_found
    other = create_reminder!(project: Project.find(2), content: 'Other project')
    @request.session[:user_id] = 2

    put :update, params: {
      project_id: @project.id,
      id: other.id,
      reminder: {
        content: 'Hijack',
        send_date: Date.new(2026, 9, 20).to_s,
        send_time: '10:15'
      }
    }
    assert_response :not_found
    assert_equal 'Other project', other.reload.content
  end

  def test_destroy_success_for_member_with_permission
    reminder = create_reminder!
    @request.session[:user_id] = 2

    assert_difference 'Reminder.count', -1 do
      delete :destroy, params: { project_id: @project.id, id: reminder.id }
    end
    assert_redirected_to project_reminders_path(@project)
    assert_equal I18n.t(:notice_reminder_deleted_successfully), flash[:notice]
    assert_nil Reminder.find_by(id: reminder.id)
  end

  def test_destroy_forbidden_without_permission
    reminder = create_reminder!
    @request.session[:user_id] = 3

    assert_no_difference 'Reminder.count' do
      delete :destroy, params: { project_id: @project.id, id: reminder.id }
    end
    assert_response :forbidden
    assert Reminder.find_by(id: reminder.id)
  end

  def test_destroy_missing_reminder_is_not_found
    @request.session[:user_id] = 2
    delete :destroy, params: { project_id: @project.id, id: 9_999_999 }
    assert_response :not_found
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
