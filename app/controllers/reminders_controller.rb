# frozen_string_literal: true

class RemindersController < ApplicationController
  before_action :find_project, :authorize
  before_action :find_reminder, only: [:show, :edit, :update, :destroy]

  def index
    @reminders = @project.reminders.includes(:created_by, :issue)
                         .order(created_at: :desc)

    respond_to do |format|
      format.html
    end
  end

  def show
  end

  def new
    @reminder = @project.reminders.build
    @reminder.send_date = Date.current

    user_tz = get_user_timezone(User.current)
    Time.use_zone(user_tz) do
      @reminder.send_time = Time.zone.now.change(sec: 0).utc
    end
  end

  def create
    @reminder = @project.reminders.build(reminder_params.except(:send_time))
    @reminder.created_by = User.current
    apply_send_time_from_params(@reminder)

    if @reminder.save
      flash[:notice] = l(:notice_reminder_created_successfully)
      redirect_to project_reminders_path(@project)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attrs = reminder_params
    attrs = attrs.except(:send_time) if apply_send_time_from_params(@reminder)

    if @reminder.update(attrs)
      flash[:notice] = l(:notice_reminder_updated_successfully)
      redirect_to project_reminders_path(@project)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @reminder.destroy
    flash[:notice] = l(:notice_reminder_deleted_successfully)
    redirect_to project_reminders_path(@project)
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_reminder
    @reminder = @project.reminders.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def reminder_params
    permitted = params.require(:reminder).permit(
      :content, :send_time, :send_date, :is_recurring,
      :recurring_type, :custom_days, :issue_id, :active
    )
    permitted[:issue_id] = nil if permitted[:issue_id].blank?
    permitted[:issue_id] = nil unless assignable_issue_id?(permitted[:issue_id])
    permitted
  end

  def assignable_issue_id?(issue_id)
    return true if issue_id.blank?

    @project.issues.visible(User.current).where(id: issue_id).exists?
  end

  def apply_send_time_from_params(reminder)
    reminder_attrs = params[:reminder]
    return false unless reminder_attrs && reminder_attrs[:send_time].present?

    user_tz = get_user_timezone(User.current)
    time_string = reminder_attrs[:send_time]
    date_string = reminder_attrs[:send_date].presence || reminder.send_date || Date.current

    Time.use_zone(user_tz) do
      user_time = Time.zone.parse("#{date_string} #{time_string}")
      reminder.send_time = user_time.utc if user_time
    end
    true
  end

  def get_user_timezone(user)
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
        case default_tz.strip
        when 'Hanoi'
          'Asia/Ho_Chi_Minh'
        else
          if ActiveSupport::TimeZone[default_tz]
            default_tz
          else
            'Asia/Ho_Chi_Minh'
          end
        end
      else
        'Asia/Ho_Chi_Minh'
      end
    end
  end
end
