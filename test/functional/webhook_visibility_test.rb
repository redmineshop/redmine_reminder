# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ReminderPluginSettingsTest < Redmine::ControllerTest
  tests SettingsController
  fixtures :projects, :users, :roles, :members, :member_roles

  SECRET = 'https://chat.example.test/spaces/SECRETPROJECTTOKEN'

  def test_plugin_settings_are_admin_only
    @request.session[:user_id] = 2
    get :plugin, params: { id: 'redmine_reminder' }
    assert_response :forbidden
  end

  def test_plugin_settings_escape_webhook_urls_for_admins
    Setting.plugin_redmine_reminder = {
      'slack_url' => '"><script>alert(1)</script>',
      'channel' => '#ops',
      'username' => 'redmine',
      'icon' => ':bell:',
      'display_watchers' => 'no',
      'google_chat_webhook_url' => SECRET
    }
    @request.session[:user_id] = 1

    get :plugin, params: { id: 'redmine_reminder' }
    assert_response :success
    assert_no_match(/<script>alert\(1\)<\/script>/, response.body)
    assert_match(/&lt;script&gt;/, response.body)
    assert_includes response.body, 'SECRETPROJECTTOKEN'
  end
end

class ProjectWebhookVisibilityTest < Redmine::ControllerTest
  tests ProjectsController
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules

  SECRET = 'https://chat.example.test/spaces/SECRETPROJECTTOKEN'

  def setup
    @project = Project.find(1)
    field = ProjectCustomField.create!(
      name: 'Google Chat Webhook',
      field_format: 'string',
      visible: true,
      searchable: true
    )
    value = @project.custom_values.find_or_initialize_by(custom_field: field)
    value.value = SECRET
    value.save!
  end

  def test_project_overview_hides_webhook_url_from_members
    @request.session[:user_id] = 2
    get :show, params: { id: @project.id }
    assert_response :success
    assert_not_includes response.body, 'SECRETPROJECTTOKEN'
  end

  def test_project_settings_hide_webhook_url_from_members
    @request.session[:user_id] = 2
    get :settings, params: { id: @project.id }
    assert_response :success
    assert_not_includes response.body, 'SECRETPROJECTTOKEN'
  end

  def test_project_overview_shows_webhook_url_to_admins
    @request.session[:user_id] = 1
    get :show, params: { id: @project.id }
    assert_response :success
    assert_includes response.body, 'SECRETPROJECTTOKEN'
  end
end
