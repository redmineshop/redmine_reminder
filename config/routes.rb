# frozen_string_literal: true

# Drawn inside Redmine's own route set. Declare /new and /edit before /:id.
get 'projects/:project_id/reminders',
    to: 'reminders#index',
    as: :project_reminders

post 'projects/:project_id/reminders',
     to: 'reminders#create'

get 'projects/:project_id/reminders/new',
    to: 'reminders#new',
    as: :new_project_reminder

get 'projects/:project_id/reminders/:id/edit',
    to: 'reminders#edit',
    as: :edit_project_reminder

patch 'projects/:project_id/reminders/:id',
      to: 'reminders#update'

put 'projects/:project_id/reminders/:id',
    to: 'reminders#update'

delete 'projects/:project_id/reminders/:id',
       to: 'reminders#destroy'

get 'projects/:project_id/reminders/:id',
    to: 'reminders#show',
    as: :project_reminder
