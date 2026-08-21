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

    it "hides the time on an all-day task's due tag" do
      Task.create!(title: "t", all_day: true, due_at: Time.zone.local(2030, 6, 5).beginning_of_day)
      get tasks_path
      expect(response.body).to include(%(>Jun 5<))
      expect(response.body).not_to match(/Jun 5, \d/)
    end

    it "shows the time on a timed task's due tag" do
      Task.create!(title: "t", all_day: false, due_at: Time.zone.local(2030, 6, 5, 14, 30))
      get tasks_path
      expect(response.body).to include("Jun 5, 2:30 PM")
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

    it "does not prefill the date field (quick-add owns the date)" do
      travel_to(Time.zone.local(2026, 2, 20, 12, 0, 0)) do
        get new_task_path
        expect(response.body).not_to include(%(value="2026-02-20"))
      end
    end

    it "renders only the quick-add title field on create (no structured controls)" do
      get new_task_path
      expect(response.body).not_to include('name="task[notes]"')
      expect(response.body).not_to include('name="task[due_date]"')
      expect(response.body).not_to include('name="task[due_time]"')
      expect(response.body).not_to include('name="task[project_id]"')
      expect(response.body).not_to include('name="task[priority]"')
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
    it "creates a task from the quick-add field, ignoring structured notes" do
      expect {
        post tasks_path, params: { task: { title: "new", notes: "keep me" } }
      }.to change(Task, :count).by(1)
      expect(response).to redirect_to(tasks_path)
      expect(Task.last.notes).to be_nil
    end

    it "parses priority from quick-add text" do
      post tasks_path, params: { task: { title: "call p2 dentist" } }
      expect(Task.last.priority).to eq(2)
      expect(Task.last.title).to eq("call dentist")
    end

    it "sets due_at from a quick-add date token" do
      travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
        post tasks_path, params: { task: { title: "Call dentist tomorrow" } }
        task = Task.last
        expect(task.title).to eq("Call dentist")
        expect(task.due_at).to eq(Time.zone.local(2026, 8, 16).beginning_of_day)
        expect(task.all_day?).to eq(true)
      end
    end

    it "persists recurrence from a quick-add phrase" do
      travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
        post tasks_path, params: { task: { title: "water plants every 3 days" } }
        task = Task.last
        expect(task.title).to eq("water plants")
        expect(task.recurrence).to eq("every 3 days")
        expect(task.due_at).to eq(Time.zone.local(2026, 8, 15).beginning_of_day)
        expect(task.all_day?).to eq(true)
      end
    end

    it "defaults a recurring task with no time to a real time anchor for sub-day recurrence" do
      travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
        post tasks_path, params: { task: { title: "water plants every 10 minutes" } }
        task = Task.last
        expect(task.recurrence).to eq("every 10 minutes")
        expect(task.all_day?).to eq(false)
        expect(task.due_at).to eq(Time.zone.local(2026, 8, 15, 10, 0, 0))
      end
    end

    it "re-renders 422 on blank title, creating nothing" do
      expect {
        post tasks_path, params: { task: { title: "" } }
      }.not_to change(Task, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "preserves the raw quick-add phrase and only the recurrence error on failure" do
      # "every 0 days" parses as a recurrence string but fails Recurrence
      # validation; the title field must keep the user's exact phrase and the
      # restored input must not show a stale blank-title error.
      post tasks_path, params: { task: { title: "water plants every 0 days" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('value="water plants every 0 days"')
      expect(response.body).to include("Recurrence is invalid")
      expect(response.body).not_to include("Title can't be blank")
    end

    it "ignores posted structured fields on create (quick-add owns them)" do
      project = Project.create!(name: "Work")
      post tasks_path, params: {
        task: { title: "t", due_date: "2026-02-20", due_time: "14:30", project_id: project.id, priority: 3 }
      }
      task = Task.last
      expect(task.due_at).to be_nil
      expect(task.project_id).to be_nil
      expect(task.priority).to eq(0)
    end

    it "shows a visible title error when a recurrence-only quick-add has no task text" do
      post tasks_path, params: { task: { title: "Every Wednesday." } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('value="Every Wednesday."')
      expect(response.body).to include("Title can&#39;t be blank")
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

    it "sets and clears recurrence via the edit form" do
      task = Task.create!(title: "old")
      patch task_path(task), params: { task: { recurrence: "every 3 days" } }
      expect(task.reload.recurrence).to eq("every 3 days")

      patch task_path(task), params: { task: { recurrence: "" } }
      expect(task.reload.recurrence).to be_nil
    end

    it "re-renders 422 on an invalid recurrence, changing nothing" do
      task = Task.create!(title: "old")
      patch task_path(task), params: { task: { recurrence: "every potatoes" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(task.reload.recurrence).to be_nil
    end

    it "anchors a sub-day recurrence set via edit on a dateless task" do
      travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
        task = Task.create!(title: "pills")
        patch task_path(task), params: { task: { recurrence: "every 10 minutes" } }
        task.reload
        expect(task.recurrence).to eq("every 10 minutes")
        expect(task.all_day?).to eq(false)
        expect(task.due_at).to eq(Time.zone.local(2026, 8, 15, 10, 0, 0))
      end
    end

    it "anchors a sub-day recurrence when the form posts blank due date and time" do
      travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
        task = Task.create!(title: "pills")
        patch task_path(task), params: { task: { recurrence: "every 10 minutes", due_date: "", due_time: "" } }
        task.reload
        expect(task.recurrence).to eq("every 10 minutes")
        expect(task.all_day?).to eq(false)
        expect(task.due_at).to eq(Time.zone.local(2026, 8, 15, 10, 0, 0))
      end
    end

    it "re-anchors a sub-day recurrence set via edit on an all-day task" do
      travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
        task = Task.create!(title: "pills", due_date: "2026-08-20")
        patch task_path(task), params: {
          task: { recurrence: "every 10 minutes", due_date: "2026-08-20", due_time: "" }
        }
        task.reload
        expect(task.all_day?).to eq(false)
        expect(task.due_at).to eq(Time.zone.local(2026, 8, 20, 10, 0, 0))
      end
    end

    it "honors an explicit blank due_date to clear a dated recurring task's anchor" do
      task = Task.create!(title: "pills", recurrence: "every 3 days", due_date: "2026-08-20")
      patch task_path(task), params: { task: { recurrence: "every 3 days", due_date: "", due_time: "" } }
      task.reload
      expect(task.due_at).to be_nil
      expect(task.all_day?).to eq(false)
      expect(task.recurrence).to eq("every 3 days")
    end

    it "does not seed a timed anchor from invalid sub-day recurrence on update" do
      travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
        task = Task.create!(title: "pills")
        patch task_path(task), params: {
          task: { recurrence: "every 0 minutes", due_date: "", due_time: "" }
        }
        expect(response).to have_http_status(:unprocessable_content)

        # Fixing the recurrence without touching the date/time fields must not
        # leave behind a seeded anchor from the failed request.
        patch task_path(task), params: { task: { recurrence: "every 10 minutes", due_date: "", due_time: "" } }
        task.reload
        expect(task.recurrence).to eq("every 10 minutes")
        expect(task.all_day?).to eq(false)
        expect(task.due_at).to eq(Time.zone.local(2026, 8, 15, 10, 0, 0))
      end
    end

    it "does not re-add today when a cleared recurring task is edited again" do
      task = Task.create!(title: "pills", recurrence: "every 3 days", due_date: "2026-08-20")
      travel_to(Time.zone.local(2026, 9, 1, 10, 0, 0)) do
        patch task_path(task), params: { task: { recurrence: "every 3 days", due_date: "", due_time: "" } }
        patch task_path(task), params: { task: { title: "pills", recurrence: "every 3 days", due_date: "", due_time: "" } }
      end

      task.reload
      expect(task.due_at).to be_nil
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
    it "completes the task and creates an occurrence" do
      task = Task.create!(title: "do it")
      patch complete_task_path(task)
      expect(response).to redirect_to(tasks_path)
      expect(Task.exists?(task.id)).to be(false)
      expect(CompletedOccurrence.last.task_title).to eq("do it")
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

    it "redirects to the task's project list" do
      project = Project.create!(name: "Work")
      task = Task.create!(title: "do it", project: project)
      patch complete_task_path(task)
      expect(response).to redirect_to(project_tasks_path(project))
    end

    it "keeps a recurring task active and out of Completed after completion" do
      travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
        task = Task.create!(title: "water plants", recurrence: "every 3 days",
                            due_at: Time.zone.local(2026, 8, 15, 9, 0))
        patch complete_task_path(task)
        task.reload
        expect(Task.count).to eq(1)
        expect(task.due_at).to eq(Time.zone.local(2026, 8, 18, 9, 0))
        expect(CompletedOccurrence.last.task_title).to eq("water plants")

        get tasks_path
        expect(response.body).to include("water plants")
      end
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
      CompletedOccurrence.create!(task_title: "done-one", priority: 0, completed_at: Time.current)
      get completed_tasks_path
      expect(response.body).to include("done-one")
      expect(response.body).not_to include("active-one")
    end

    it "orders most-recently-completed first" do
      CompletedOccurrence.create!(task_title: "older", priority: 0, completed_at: 2.hours.ago)
      CompletedOccurrence.create!(task_title: "newer", priority: 0, completed_at: 1.minute.ago)
      get completed_tasks_path
      expect(response.body.index("newer")).to be < response.body.index("older")
    end
  end

  describe "organization: form fields (slice 2)" do
    it "creates an Inbox task when no #project token is present" do
      post tasks_path, params: { task: { title: "t" } }
      expect(Task.last.project_id).to be_nil
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

    it "Inbox shows an overdue nil-project task, marked with the danger background class" do
      Task.create!(title: "overdue-inbox-task", due_at: 1.day.ago)
      get tasks_path
      expect(response.body).to include("overdue-inbox-task")
      expect(Capybara.string(response.body)).to have_css(
        "tr.has-background-danger-light", text: "overdue-inbox-task"
      )
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

    it "renders a badge for P1 and none for P0" do
      Task.create!(title: "urgent", priority: 3, due_at: Time.current)
      get tasks_path
      expect(Capybara.string(response.body)).to have_css("span.tag.is-danger", text: "P1")

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

  describe "quick-add project tokens (slice 4c)" do
    it "reuses an existing project on exact match" do
      project = Project.create!(name: "Work")
      post tasks_path, params: { task: { title: "Call #Work dentist" } }
      task = Task.last
      expect(task.project).to eq(project)
      expect(task.title).to eq("Call dentist")
    end

    it "reuses an existing project case-insensitively" do
      Project.create!(name: "Work")
      post tasks_path, params: { task: { title: "Call #work dentist" } }
      expect(Task.last.project.name).to eq("Work")
    end

    it "creates the project directly when no near-miss exists" do
      post tasks_path, params: { task: { title: "Call #Errand dentist" } }
      task = Task.last
      expect(task.project.name).to eq("Errand")
      expect(task.title).to eq("Call dentist")
    end

    it "re-renders with a confirm banner on a near-miss, creating nothing" do
      Project.create!(name: "Work")
      expect {
        post tasks_path, params: { task: { title: "Call #Wrok dentist" } }
      }.not_to change(Task, :count)
      expect(Project.find_by(name: "Wrok")).to be_nil
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Did you mean")
      expect(response.body).to include("#Work")
    end

    it "creates the task in the suggested project when Use existing is submitted" do
      project = Project.create!(name: "Work")
      post tasks_path, params: { task: { title: "Call #Wrok dentist" }, project_name: "Work" }
      task = Task.last
      expect(task.project).to eq(project)
      expect(task.title).to eq("Call dentist")
    end

    it "creates the misspelled project when Create anyway is submitted" do
      Project.create!(name: "Work")
      post tasks_path, params: { task: { title: "Call #Wrok dentist" }, force_create_project: "true" }
      task = Task.last
      expect(task.project.name).to eq("Wrok")
      expect(task.title).to eq("Call dentist")
    end
  end

  describe "GET /tasks/today" do
    it "shows overdue, due-today, and undated tasks; hides due-tomorrow and completed" do
      overdue   = Task.create!(title: "overdue-task", due_at: 1.day.ago)
      due_today = Task.create!(title: "today-task", due_at: Time.current)
      undated   = Task.create!(title: "undated-task")
      tomorrow  = Task.create!(title: "tomorrow-task", due_at: 1.day.from_now)
      completed = Task.create!(title: "completed-task")
      completed.complete!

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

  describe "GET /tasks/overdue" do
    it "shows only tasks due before today" do
      Task.create!(title: "overdue-task", due_at: 1.day.ago)
      Task.create!(title: "today-task", due_at: Time.current)
      Task.create!(title: "undated-task")
      Task.create!(title: "tomorrow-task", due_at: 1.day.from_now)
      completed = Task.create!(title: "completed-task", due_at: 1.day.ago)
      completed.complete!

      get overdue_tasks_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("overdue-task")
      expect(response.body).not_to include("today-task")
      expect(response.body).not_to include("undated-task")
      expect(response.body).not_to include("tomorrow-task")
      expect(response.body).not_to include("completed-task")
    end

    it "marks the overdue row with the danger background class" do
      Task.create!(title: "overdue-task", due_at: 1.day.ago)
      get overdue_tasks_path
      expect(response.body).to include("has-background-danger-light")
    end
  end

  describe "GET /tasks/due_since" do
    it "returns a timed task due in (since, now] with id, title, due_at, and a now field" do
      task = Task.create!(title: "due-now", all_day: false, due_at: 1.minute.ago)

      get due_since_tasks_path, params: { since: 5.minutes.ago.iso8601 }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["now"]).to be_present
      expect(body["tasks"]).to eq([ { "id" => task.id, "title" => "due-now", "due_at" => task.due_at.utc.iso8601(6) } ])
    end

    it "excludes an all_day task that is technically due" do
      Task.create!(title: "all-day", all_day: true, due_at: Time.current.beginning_of_day)
      timed = Task.create!(title: "timed", all_day: false, due_at: 1.minute.ago)

      get due_since_tasks_path, params: { since: 1.hour.ago.iso8601 }
      body = JSON.parse(response.body)
      expect(body["tasks"].map { |t| t["title"] }).to eq([ "timed" ])
    end

    it "excludes a task with due_at at or before since (already overdue at load)" do
      travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
        due_at = 5.minutes.ago
        Task.create!(title: "boundary", all_day: false, due_at: due_at)
        in_window = Task.create!(title: "in-window", all_day: false, due_at: 1.minute.ago)

        get due_since_tasks_path, params: { since: due_at.iso8601 }
        body = JSON.parse(response.body)
        expect(body["tasks"].map { |t| t["title"] }).to eq([ "in-window" ])
      end
    end

    it "excludes a task due in the future" do
      Task.create!(title: "future", all_day: false, due_at: 1.hour.from_now)

      get due_since_tasks_path, params: { since: 1.day.ago.iso8601 }
      body = JSON.parse(response.body)
      expect(body["tasks"]).to be_empty
    end

    it "returns 400 for an unparseable since" do
      get due_since_tasks_path, params: { since: "not-a-date" }
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)["error"]).to eq("since must be ISO8601")
    end

    it "serializes now with at least the precision of a returned due_at (no re-toast)" do
      travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0) + 0.25) do
        task = Task.create!(title: "ms-task", all_day: false, due_at: Time.current)

        get due_since_tasks_path, params: { since: (Time.current - 1).iso8601(6) }
        body = JSON.parse(response.body)
        expect(body["tasks"].map { |t| t["title"] }).to eq([ "ms-task" ])
        # The client anchors on response.now; a truncated now below the task's
        # due_at would put the task back in the poll window and re-toast it.
        expect(Time.iso8601(body["now"])).to be >= Time.iso8601(body["tasks"].first["due_at"])
      end
    end
  end
end
