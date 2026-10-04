# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class WebhookFieldTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles

  def test_saving_a_webhook_field_hides_it_from_non_admins
    field = ProjectCustomField.new(
      name: 'Google Chat Webhook',
      field_format: 'string',
      visible: true,
      searchable: true
    )
    field.role_ids = [Role.find(1).id]
    field.save!

    field.reload
    assert_not field.visible?
    assert_not field.searchable?
    assert_empty field.role_ids
  end

  def test_restrict_existing_hides_a_legacy_visible_webhook_field
    field = ProjectCustomField.create!(name: 'Slack URL', field_format: 'string')
    field.update_columns(visible: true, searchable: true)
    field.roles << Role.find(2)

    RedmineReminder::WebhookFields.restrict!(field.reload)

    field.reload
    assert_not field.visible?
    assert_not field.searchable?
    assert_empty field.role_ids
  end

  def test_other_project_fields_stay_visible
    field = ProjectCustomField.create!(
      name: 'Release channel',
      field_format: 'string',
      visible: true
    )
    assert field.reload.visible?
  end
end
