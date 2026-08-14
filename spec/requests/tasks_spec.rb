require "rails_helper"

RSpec.describe "Tasks", type: :request do
  describe "GET /tasks" do
    it "lists active task titles" do
      Task.create!(title: "buy milk")
      get tasks_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("buy milk")
    end

    it "orders by due_at asc with NULLs last, created_at desc breaking ties" do
      no_due   = Task.create!(title: "no-due")
      tomorrow = Task.create!(title: "tomorrow", due_at: 1.day.from_now)
      today    = Task.create!(title: "today", due_at: Time.current)
      tie_old  = Task.create!(title: "tie-old", due_at: Time.new(2030, 1, 1, 9))
      tie_new  = Task.create!(title: "tie-new", due_at: Time.new(2030, 1, 1, 9))

      get tasks_path
      order = %w[today tomorrow tie-new tie-old no-due].map { |t| response.body.index(t) }
      expect(order).to eq(order.sort)
    end
  end

  describe "GET /tasks/new" do
    it "renders the form" do
      get new_task_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /tasks/:id/edit" do
    it "pre-fills title, notes, due_at" do
      due = Time.zone.local(2030, 3, 4, 9, 30)
      task = Task.create!(title: "edit me", notes: "some notes", due_at: due)
      get edit_task_path(task)
      expect(response.body).to include("edit me")
      expect(response.body).to include("some notes")
      expect(response.body).to include(due.strftime("%Y-%m-%dT%H:%M"))
    end
  end

  describe "a request for a missing task" do
    it "returns 404 on edit" do
      get edit_task_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 on complete" do
      patch complete_task_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /tasks" do
    it "creates a task, persists notes, and redirects" do
      expect {
        post tasks_path, params: { task: { title: "new", notes: "keep me" } }
      }.to change(Task, :count).by(1)
      expect(response).to redirect_to(tasks_path)
      expect(Task.last.notes).to eq("keep me")
    end

    it "re-renders 422 on blank title, creating nothing" do
      expect {
        post tasks_path, params: { task: { title: "" } }
      }.not_to change(Task, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /tasks/:id" do
    it "updates on valid params" do
      task = Task.create!(title: "old")
      patch task_path(task), params: { task: { title: "new" } }
      expect(task.reload.title).to eq("new")
    end

    it "re-renders 422 on invalid params, changing nothing" do
      task = Task.create!(title: "old")
      patch task_path(task), params: { task: { title: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(task.reload.title).to eq("old")
    end
  end

  describe "DELETE /tasks/:id" do
    it "removes the task" do
      task = Task.create!(title: "gone")
      expect { delete task_path(task) }.to change(Task, :count).by(-1)
    end
  end

  describe "PATCH /tasks/:id/complete" do
    it "completes the task and redirects to the index" do
      task = Task.create!(title: "do it")
      patch complete_task_path(task)
      expect(response).to redirect_to(tasks_path)
      expect(task.reload).to be_completed
    end

    it "drops the task from the active index" do
      task = Task.create!(title: "do it")
      patch complete_task_path(task)
      get tasks_path
      expect(response.body).not_to include("do it")
    end

    it "shows a confirmation flash after redirect" do
      task = Task.create!(title: "do it")
      patch complete_task_path(task)
      follow_redirect!
      expect(response.body).to include("Task completed")
    end
  end

  describe "GET /tasks/completed" do
    it "lists completed titles and hides active ones" do
      Task.create!(title: "active-one")
      Task.create!(title: "done-one", completed_at: Time.current)
      get completed_tasks_path
      expect(response.body).to include("done-one")
      expect(response.body).not_to include("active-one")
    end

    it "orders most-recently-completed first" do
      Task.create!(title: "older", completed_at: 2.hours.ago)
      Task.create!(title: "newer", completed_at: 1.minute.ago)
      get completed_tasks_path
      expect(response.body.index("newer")).to be < response.body.index("older")
    end

    it "shows completed_at in the app's local time zone, not UTC" do
      # 2030-06-01 16:00 UTC == 12:00 PM US Eastern (EDT). If the app rendered
      # UTC, the page would read 4:00 PM.
      Task.create!(title: "tz-check", completed_at: Time.utc(2030, 6, 1, 16, 0))
      get completed_tasks_path
      expect(response.body).to include("12:00 PM")
      expect(response.body).not_to include("4:00 PM")
    end
  end
end
