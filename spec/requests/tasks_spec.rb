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

    it "carries return_to through as a hidden field when present" do
      get new_task_path(return_to: today_tasks_path)
      expect(response.body).to include(%(value="#{today_tasks_path}"))
    end

    it "defaults the date field to today" do
      travel_to(Time.zone.local(2026, 2, 20, 12, 0, 0)) do
        get new_task_path
        expect(response.body).to include(%(value="2026-02-20"))
      end
    end
  end

  describe "GET /tasks/:id/edit" do
    it "pre-fills title, notes, due_date, due_time" do
      due = Time.zone.local(2030, 3, 4, 9, 30)
      task = Task.create!(title: "edit me", notes: "some notes", due_at: due)
      get edit_task_path(task)
      expect(response.body).to include("edit me")
      expect(response.body).to include("some notes")
      expect(response.body).to include(due.strftime("%Y-%m-%d"))
      expect(response.body).to include(due.strftime("%H:%M"))
    end
  end

  describe "edit link carries return_to back to the originating view" do
    it "Today's edit link points at /tasks/:id/edit?return_to=/tasks/today" do
      Task.create!(title: "edit me")
      get today_tasks_path
      expect(response.body).to match(%r{/tasks/\d+/edit\?return_to=%2Ftasks%2Ftoday})
    end
  end

  describe "Cancel link on the edit form" do
    def cancel_href(body)
      Nokogiri::HTML(body).at_xpath("//a[text()='Cancel']")["href"]
    end

    it "points back to return_to when present" do
      task = Task.create!(title: "t")
      get edit_task_path(task, return_to: today_tasks_path)
      expect(cancel_href(response.body)).to eq(today_tasks_path)
    end

    it "ignores a protocol-relative return_to and falls back to task_list_path" do
      task = Task.create!(title: "t")
      get edit_task_path(task, return_to: "//evil.com")
      expect(cancel_href(response.body)).to eq(tasks_path)
    end

    it "falls back to task_list_path when return_to is absent" do
      task = Task.create!(title: "t")
      get edit_task_path(task)
      expect(cancel_href(response.body)).to eq(tasks_path)
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

    it "creates an all-day task when only due_date is submitted" do
      post tasks_path, params: { task: { title: "t", due_date: "2026-02-20" } }
      task = Task.last
      expect(task.all_day?).to eq(true)
      expect(task.due_at).to eq(Time.zone.local(2026, 2, 20).beginning_of_day)
    end

    it "creates a timed task when due_date and due_time are both submitted" do
      post tasks_path, params: { task: { title: "t", due_date: "2026-02-20", due_time: "14:30" } }
      task = Task.last
      expect(task.all_day?).to eq(false)
      expect(task.due_at).to eq(Time.zone.local(2026, 2, 20, 14, 30))
    end

    it "redirects back to return_to when present, instead of task_list_path" do
      post tasks_path, params: { task: { title: "t" }, return_to: today_tasks_path }
      expect(response).to redirect_to(today_tasks_path)
    end

    it "ignores a protocol-relative return_to and falls back to task_list_path" do
      post tasks_path, params: { task: { title: "t" }, return_to: "//evil.com" }
      expect(response).to redirect_to(tasks_path)
    end

    it "falls back to task_list_path when return_to is absent" do
      post tasks_path, params: { task: { title: "t" } }
      expect(response).to redirect_to(tasks_path)
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

    it "redirects back to Today when return_to param present" do
      task = Task.create!(title: "old")
      patch task_path(task), params: { task: { title: "new" }, return_to: today_tasks_path }
      expect(response).to redirect_to(today_tasks_path)
    end

    it "redirects back to Upcoming when return_to param present" do
      task = Task.create!(title: "old")
      patch task_path(task), params: { task: { title: "new" }, return_to: upcoming_tasks_path }
      expect(response).to redirect_to(upcoming_tasks_path)
    end

    it "ignores a protocol-relative return_to and falls back to task_list_path" do
      task = Task.create!(title: "old")
      patch task_path(task), params: { task: { title: "new" }, return_to: "//evil.com" }
      expect(response).to redirect_to(tasks_path)
    end

    it "falls back to task_list_path with no referer" do
      task = Task.create!(title: "old")
      patch task_path(task), params: { task: { title: "new" } }
      expect(response).to redirect_to(tasks_path)
    end
  end

  describe "DELETE /tasks/:id" do
    it "removes the task" do
      task = Task.create!(title: "gone")
      expect { delete task_path(task) }.to change(Task, :count).by(-1)
    end

    it "redirects back to Today when referred from Today" do
      task = Task.create!(title: "gone")
      delete task_path(task), headers: { "HTTP_REFERER" => today_tasks_path }
      expect(response).to redirect_to(today_tasks_path)
    end

    it "redirects back to Upcoming when referred from Upcoming" do
      task = Task.create!(title: "gone")
      delete task_path(task), headers: { "HTTP_REFERER" => upcoming_tasks_path }
      expect(response).to redirect_to(upcoming_tasks_path)
    end

    it "falls back to task_list_path with no referer" do
      task = Task.create!(title: "gone")
      delete task_path(task)
      expect(response).to redirect_to(tasks_path)
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

    it "redirects back to Today when referred from Today" do
      task = Task.create!(title: "do it")
      patch complete_task_path(task), headers: { "HTTP_REFERER" => today_tasks_path }
      expect(response).to redirect_to(today_tasks_path)
    end

    it "redirects back to Upcoming when referred from Upcoming" do
      task = Task.create!(title: "do it")
      patch complete_task_path(task), headers: { "HTTP_REFERER" => upcoming_tasks_path }
      expect(response).to redirect_to(upcoming_tasks_path)
    end

    it "falls back to task_list_path with no referer" do
      task = Task.create!(title: "do it")
      patch complete_task_path(task)
      expect(response).to redirect_to(tasks_path)
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
  end

  describe "organization: form fields (slice 2)" do
    it "assigns a project on create" do
      project = Project.create!(name: "Work")
      post tasks_path, params: { task: { title: "t", project_id: project.id } }
      expect(Task.last.project).to eq(project)
    end

    it "leaves project nil (Inbox) when blank" do
      post tasks_path, params: { task: { title: "t", project_id: "" } }
      expect(Task.last.project_id).to be_nil
    end

    it "persists priority" do
      post tasks_path, params: { task: { title: "t", priority: 3 } }
      expect(Task.last.priority).to eq(3)
    end

    it "associates labels on create" do
      a = Label.create!(name: "a")
      b = Label.create!(name: "b")
      post tasks_path, params: { task: { title: "t", label_ids: [ a.id, b.id ] } }
      expect(Task.last.labels).to contain_exactly(a, b)
    end

    it "clears labels when the checkbox set submits empty" do
      a = Label.create!(name: "a")
      task = Task.create!(title: "t", labels: [ a ])
      patch task_path(task), params: { task: { title: "t", label_ids: [ "" ] } }
      expect(task.reload.labels).to be_empty
    end

    it "changes project, priority, and labels together on update" do
      project = Project.create!(name: "Work")
      label = Label.create!(name: "a")
      task = Task.create!(title: "t")
      patch task_path(task), params: {
        task: { title: "t", project_id: project.id, priority: 2, label_ids: [ label.id ] }
      }
      task.reload
      expect(task.project).to eq(project)
      expect(task.priority).to eq(2)
      expect(task.labels).to contain_exactly(label)
    end

    it "pre-checks current labels on the edit form" do
      label = Label.create!(name: "chosen")
      task = Task.create!(title: "t", labels: [ label ])
      get edit_task_path(task)
      expect(Capybara.string(response.body)).to have_css(
        "input[type=checkbox][name='task[label_ids][]'][value='#{label.id}'][checked]"
      )
    end
  end

  describe "organization: Inbox + per-project views (slice 2)" do
    it "Inbox shows only nil-project active tasks" do
      project = Project.create!(name: "Work")
      Task.create!(title: "inbox-task")
      Task.create!(title: "work-task", project: project)
      get tasks_path
      expect(response.body).to include("inbox-task")
      expect(response.body).not_to include("work-task")
    end

    it "per-project view shows only that project's active tasks, headed by its name" do
      project = Project.create!(name: "Work")
      other = Project.create!(name: "Home")
      Task.create!(title: "work-task", project: project)
      Task.create!(title: "home-task", project: other)
      Task.create!(title: "inbox-task")
      get project_tasks_path(project)
      expect(response.body).to include("work-task")
      expect(response.body).to include("Work")
      expect(response.body).not_to include("home-task")
      expect(response.body).not_to include("inbox-task")
    end

    it "renders a badge for P3 and none for P0" do
      Task.create!(title: "urgent", priority: 3, due_at: Time.current)
      get tasks_path
      expect(Capybara.string(response.body)).to have_css("span.tag.is-danger", text: "P3")

      Task.delete_all
      Task.create!(title: "plain", priority: 0, due_at: Time.current)
      get tasks_path
      expect(response.body).not_to match(/>P[123]</)
    end

    it "renders each assigned label name on the row" do
      label = Label.create!(name: "errand")
      Task.create!(title: "t", labels: [ label ])
      get tasks_path
      expect(response.body).to include("errand")
    end

    it "redirects to the project list after completing a project task" do
      project = Project.create!(name: "Work")
      task = Task.create!(title: "t", project: project)
      patch complete_task_path(task)
      expect(response).to redirect_to(project_tasks_path(project))
    end

    it "redirects to Inbox after completing an inbox task" do
      task = Task.create!(title: "t")
      patch complete_task_path(task)
      expect(response).to redirect_to(tasks_path)
    end

    it "returns 404 for a missing project view" do
      get project_tasks_path(project_id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /tasks/today" do
    it "shows overdue, due-today, and undated tasks; hides due-tomorrow and completed" do
      overdue   = Task.create!(title: "overdue-task", due_at: 1.day.ago)
      due_today = Task.create!(title: "today-task", due_at: Time.current)
      undated   = Task.create!(title: "undated-task")
      tomorrow  = Task.create!(title: "tomorrow-task", due_at: 1.day.from_now)
      done      = Task.create!(title: "completed-task", completed_at: Time.current)

      get today_tasks_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("overdue-task")
      expect(response.body).to include("today-task")
      expect(response.body).to include("undated-task")
      expect(response.body).not_to include("tomorrow-task")
      expect(response.body).not_to include("completed-task")
    end

    it "shows tasks from any project (no project_id scoping)" do
      project = Project.create!(name: "Work")
      Task.create!(title: "project-today-task", due_at: Time.current, project: project)
      get today_tasks_path
      expect(response.body).to include("project-today-task")
    end
  end

  describe "GET /tasks/upcoming" do
    it "shows a due-tomorrow task; hides undated, due-today, day-8, and overdue tasks" do
      Task.create!(title: "tomorrow-task", due_at: 1.day.from_now)
      Task.create!(title: "undated-task")
      Task.create!(title: "today-task", due_at: Time.current)
      Task.create!(title: "day8-task", due_at: 8.days.from_now)
      Task.create!(title: "overdue-task", due_at: 1.day.ago)

      get upcoming_tasks_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("tomorrow-task")
      expect(response.body).not_to include("undated-task")
      expect(response.body).not_to include("today-task")
      expect(response.body).not_to include("day8-task")
      expect(response.body).not_to include("overdue-task")
    end

    it "groups same-date tasks under one heading, ascending by date" do
      Task.create!(title: "tomorrow-a", due_at: 1.day.from_now)
      Task.create!(title: "tomorrow-b", due_at: 1.day.from_now)
      Task.create!(title: "day3-task", due_at: 3.days.from_now)

      get upcoming_tasks_path
      expect(response.body).to include("tomorrow-a")
      expect(response.body).to include("tomorrow-b")

      tomorrow_index = response.body.index(1.day.from_now.to_date.strftime("%A, %b %-d"))
      day3_index = response.body.index(3.days.from_now.to_date.strftime("%A, %b %-d"))
      expect(tomorrow_index).to be < day3_index
    end
  end
end
