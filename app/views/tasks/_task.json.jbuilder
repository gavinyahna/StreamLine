json.extract! task, :id, :title, :description, :start_date, :end_date, :event, :user_id, :created_at, :updated_at
json.url task_url(task, format: :json)
