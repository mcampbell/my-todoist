require "rails_helper"

# rack_test driver: no JS needed, matches spec/system/task_flow_spec.rb.
RSpec.describe "Task display", type: :system do
  before { driven_by(:rack_test) }

  it "renders a p1-p4 priority badge but hides the p4 baseline" do
    Task.create!(title: "P3 task", priority: 1)
    Task.create!(title: "Baseline", priority: 0)

    visit tasks_path

    expect(page).to have_css(".tag.is-info", text: "P3")
    within("tr", text: "Baseline") { expect(page).to have_no_css(".tag") }
  end

  it "colors P2 and P1 badges distinctly from P3" do
    Task.create!(title: "P2 task", priority: 2)
    Task.create!(title: "P1 task", priority: 3)

    visit tasks_path

    expect(page).to have_css(".tag.is-warning", text: "P2")
    expect(page).to have_css(".tag.is-danger", text: "P1")
  end

  it "highlights an overdue task's row" do
    travel_to(Time.zone.local(2026, 8, 17, 10, 0, 0)) do
      Task.create!(title: "Stale", due_date: "2026-08-10")

      visit tasks_path

      expect(page).to have_css("tr.has-background-danger-light", text: "Stale")
    end
  end

  it "does not highlight a task due later today" do
    travel_to(Time.zone.local(2026, 8, 17, 10, 0, 0)) do
      Task.create!(title: "Later today", due_date: "2026-08-17", due_time: "18:00")

      visit tasks_path

      expect(page).to have_no_css("tr.has-background-danger-light", text: "Later today")
    end
  end

  it "formats an all-day due tag without a time, and a timed due tag with one" do
    Task.create!(title: "Errand", due_date: "2026-08-20")
    Task.create!(title: "Meeting", due_date: "2026-08-20", due_time: "14:30")

    visit tasks_path

    expect(page).to have_content("Aug 20")
    expect(page).to have_content("Aug 20, 2:30 PM")
  end

  it "renders a recurrence tag on a recurring task" do
    Task.create!(title: "Water plants", recurrence: "every day", due_date: "2026-08-20")

    visit tasks_path

    expect(page).to have_content("↻ every day")
  end

  it "renders label tags sorted by name" do
    zebra = Label.create!(name: "zebra")
    apple = Label.create!(name: "apple")
    Task.create!(title: "Errand", label_ids: [ zebra.id, apple.id ])

    visit tasks_path

    within("tr", text: "Errand") do
      tags = all(".tag").map(&:text)
      expect(tags.index("apple")).to be < tags.index("zebra")
    end
  end

  it "lists today's and undated tasks on the Today page, with an empty state otherwise" do
    travel_to(Time.zone.local(2026, 8, 17, 10, 0, 0)) do
      Task.create!(title: "Due today", due_date: "2026-08-17")
      Task.create!(title: "Undated")
      Task.create!(title: "Due next week", due_date: "2026-08-24")

      visit today_tasks_path

      expect(page).to have_content("Due today")
      expect(page).to have_content("Undated")
      expect(page).to have_no_content("Due next week")
    end
  end

  it "shows the Today page empty state when nothing is due" do
    visit today_tasks_path

    expect(page).to have_content("Nothing due today.")
  end

  it "lists an overdue task on the Overdue page, with an empty state otherwise" do
    travel_to(Time.zone.local(2026, 8, 17, 10, 0, 0)) do
      Task.create!(title: "Stale", due_date: "2026-08-10")

      visit overdue_tasks_path

      expect(page).to have_content("Stale")
    end
  end

  it "shows the Overdue page empty state when nothing is overdue" do
    visit overdue_tasks_path

    expect(page).to have_content("Nothing overdue.")
  end

  it "groups upcoming tasks under a per-date heading" do
    travel_to(Time.zone.local(2026, 8, 17, 10, 0, 0)) do
      Task.create!(title: "Dentist", due_date: "2026-08-19")

      visit upcoming_tasks_path

      expect(page).to have_css("h2", text: "Wednesday, Aug 19")
      within("h2 ~ table", text: "Dentist") { expect(page).to have_content("Dentist") }
    end
  end

  it "shows the Upcoming page empty state when nothing is due in the next 7 days" do
    visit upcoming_tasks_path

    expect(page).to have_content("Nothing due in the next 7 days.")
  end
end
