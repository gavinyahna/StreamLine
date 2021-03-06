require "google/apis/calendar_v3"
require "google/api_client/client_secrets.rb"

class TasksController < ApplicationController
  before_action :set_task, only: [:show, :edit, :update, :destroy]
  before_action :set_google_service, only: [:index, :create, :update, :destroy]

  # GET /tasks
  # GET /tasks.json
  def index
    @user = current_user
    if (@user.populated == false) 
      populate_database
      @user.populated = true
      @user.save!
    elsif @user.current_login - @user.last_login > 30
      populate_database
    end
    @tasks = @user.tasks.where(start: params[:start]..params[:end])
  end

  def populate_database
    tasks = get_calendar_events
    tasks.items.each do |task|
      if (task.status != "cancelled")
        tmp_task = Task.new
        tmp_task.user_id = current_user.id
        tmp_task.google_id = task.id
        tmp_task.title = task.summary
        tmp_task.description = task.description.nil? ? "" : task.description

        # All day events from Google only have date
        if (task.start.date_time.nil? && task.end.date_time.nil?)
          # when time is missing, set time to midnight of that night
          tmp_task.start = task.start.date.to_time
          tmp_task.end = task.end.date.to_time
        else
          tmp_task.start = task.start.date_time
          tmp_task.end = task.end.date_time
        end
        tmp_task.save
      end
      # default color is purple
      tmp_task.color = 'purple'
      tmp_task.save
    end
  end

  def get_calendar_events
    # Get a list of calendars
    if @user.last_login.nil?
      tasks_list = @service.list_events(
      'primary', 
      single_events: true,
      order_by: 'startTime',
      time_min: (Time.now - 60*60*24*14).iso8601,
      )
    else
      tasks_list = @service.list_events(
      'primary', 
      single_events: true,
      order_by: 'startTime',
      updated_min: @user.last_login.localtime.iso8601
      )
    end
    @user.last_login = @user.current_login
    @user.save!
    tasks_list
  end
  
  # GET /tasks/1
  # GET /tasks/1.json
  def show
  end

  # GET /tasks/new
  def new
    @task = Task.new
  end

  # GET /tasks/1/edit
  def edit
  end

  # POST /tasks
  # POST /tasks.json
  def create
    note_id = task_params["note_id"]
    new_task_params = task_params
    new_task_params.delete("note_id")
    @task = Task.new(new_task_params)
    if task_params["color"].nil?
      @task.color = 'purple'
    else
      @task.color = task_params["color"]
    end
    # when note gets dropped on calendar
    if (!note_id.nil?)
      note = Note.find(note_id)
      @task.title = note.title
      @task.description = note.description
      @task.color = note.color
    end
    @task.start = task_params["start"].to_time.utc
    @task.end = task_params["end"].to_time.utc
    # note dragged on all-day area
    if (@task.start == @task.end)
      @task.end = @task.start + 1.days
    end
    # for Google API post
    event = Google::Apis::CalendarV3::Event.new({
      start: {date_time: @task.start.localtime.iso8601},
      end: {date_time: @task.end.localtime.iso8601},
      summary: @task.title,
      description: @task.description
    })
    event = @service.insert_event("primary", event)
    @task.google_id = event.id
    @task.user_id = current_user.id
    @task.save
  end

  # PATCH/PUT /tasks/1
  # PATCH/PUT /tasks/1.json
  def update
    # avoids API call when only color is changed
    if (@task.changed_only_color(task_params))
      @task.color = task_params["color"]
      return @task.save
    end
    @task.start = task_params["start"].to_time.utc
    @task.end = task_params["end"].to_time.utc
    # normal event dragged to all-day zone
    if (@task.start == @task.end && @task.start.localtime == @task.start.localtime.midnight)
      @task.end = @task.start + 1.days
    # all-day event dragged to normal zone
    elsif (@task.start == @task.end)
      @task.end = @task.start + 1.hours
    end
    @task.title = task_params["title"]
    @task.description = task_params["description"]
    # only change color if new color specified
    if !task_params["color"].nil?
      @task.color = task_params["color"]
    end
    # For Google API POST request
    event = @service.get_event("primary", @task.google_id)
    event.summary = @task.title
    event.start = {date_time: @task.start.localtime.iso8601}
    event.end = {date_time: @task.end.localtime.iso8601}
    event.description = @task.description
    event = @service.update_event("primary", @task.google_id, event)
    @task.save
  end

  # DELETE /tasks/1
  # DELETE /tasks/1.json
  def destroy
    # Google API DELETE request
    @service.delete_event("primary", @task.google_id)
    @task.destroy
  end

  # client secrets generated from secrets.yml file
  def google_secret
    Google::APIClient::ClientSecrets.new(
      { "web" =>
        { "access_token" => current_user.oauth_token,
          "refresh_token" => current_user.oauth_refresh_token,
          "client_id" => Rails.application.secrets.google_client_id,
          "client_secret" => Rails.application.secrets.google_client_secret,
        }
      }
    )
  end

  # Google client gem method for authorization refresh would send
  # an invalid request on Heroku. For future use

  # def refresh_auth
  #   begin
  #     if current_user.expired?
  #       @service.authorization.refresh!
  #       current_user.update_attributes(
  #         oauth_token: @service.authorization.access_token,
  #         oauth_refresh_token: @service.authorization.refresh_token,
  #         oauth_expires_at: @service.authorization.expires_at.iso8601
  #       )
  #   end
  #   rescue => e
  #     raise e.message
  #   end
  #   @service
  # end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_task
      @task = Task.find(params[:id])
    end

    # Sets Google Service object that is used for API calls
    def set_google_service
      # Initialize Google Calendar API
      @service = Google::Apis::CalendarV3::CalendarService.new
      # Use google keys to authorize (from local file)
      @service.authorization = google_secret.to_authorization
      @service.authorization.grant_type = "refresh_token"
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def task_params
      params.require(:task).permit(:id, :title, :date_range, :start, :end, :color, :description, :note_id)
    end
end
