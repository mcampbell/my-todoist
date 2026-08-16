require "rails_helper"

# rack_test driver: no JS needed, matches spec/system/task_flow_spec.rb.
RSpec.describe "Recurrence models", type: :system do
  before { driven_by(:rack_test) }

  def complete(title)
    find("button[aria-label='Complete #{title}']").click
  end

  it "steps a daily interval recurrence forward by whole intervals from the original due date" do
    travel_to(Time.zone.local(2026, 8, 17, 10, 0, 0)) do
      visit new_task_path
      fill_in "Title", with: "Water plants every day"
      click_button "Save"
    end

    travel_to(Time.zone.local(2026, 8, 17, 15, 0, 0)) do
      visit tasks_path
      complete("Water plants")
    end

    task = Task.last
    expect(task.due_at).to eq(Time.zone.local(2026, 8, 18).beginning_of_day)
    expect(task.all_day?).to eq(true)
  end

  it "advances a weekday-name recurrence to the next matching weekday, preserving phase" do
    # Aug 17 2026 is a Monday.
    travel_to(Time.zone.local(2026, 8, 17, 10, 0, 0)) do
      visit new_task_path
      fill_in "Title", with: "Team sync every monday"
      click_button "Save"
    end

    travel_to(Time.zone.local(2026, 8, 17, 15, 0, 0)) do
      visit tasks_path
      expect(page).to have_content("↻ every monday")
      complete("Team sync")
    end

    task = Task.last
    expect(task.due_at).to eq(Time.zone.local(2026, 8, 24).beginning_of_day)
  end

  it "steps a business-day (workday) recurrence over the weekend" do
    # Aug 21 2026 is a Friday.
    travel_to(Time.zone.local(2026, 8, 21, 10, 0, 0)) do
      visit new_task_path
      fill_in "Title", with: "Standup every workday"
      click_button "Save"
    end

    travel_to(Time.zone.local(2026, 8, 21, 15, 0, 0)) do
      visit tasks_path
      complete("Standup")
    end

    task = Task.last
    expect(task.due_at).to eq(Time.zone.local(2026, 8, 24).beginning_of_day)
  end

  it "reschedules a rolling (every!) weekday recurrence from completion time, not the original due date" do
    travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
      visit new_task_path
      fill_in "Title", with: "Backup laptop every! monday"
      click_button "Save"
    end

    # Complete on a Wednesday, well after the original (Saturday) due date.
    travel_to(Time.zone.local(2026, 8, 19, 9, 0, 0)) do
      visit tasks_path
      complete("Backup laptop")
    end

    task = Task.last
    expect(task.due_at).to eq(Time.zone.local(2026, 8, 24, 9, 0, 0))
  end

  it "skips a full cycle for an 'every other' ordinal count" do
    travel_to(Time.zone.local(2026, 8, 17, 10, 0, 0)) do
      visit new_task_path
      fill_in "Title", with: "Trash day every other monday"
      click_button "Save"
    end

    travel_to(Time.zone.local(2026, 8, 17, 15, 0, 0)) do
      visit tasks_path
      complete("Trash day")
    end

    task = Task.last
    expect(task.due_at).to eq(Time.zone.local(2026, 8, 31).beginning_of_day)
  end

  it "lands a month recurrence on the 1st of the target month, discarding day-of-month" do
    travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
      visit new_task_path
      fill_in "Title", with: "Pay rent every month"
      click_button "Save"
    end

    travel_to(Time.zone.local(2026, 8, 15, 15, 0, 0)) do
      visit tasks_path
      complete("Pay rent")
    end

    task = Task.last
    expect(task.due_at).to eq(Time.zone.local(2026, 9, 1).beginning_of_day)
  end

  it "seeds a real time-of-day anchor for sub-day recurrences so the task never renders as all-day" do
    travel_to(Time.zone.local(2026, 8, 17, 9, 30, 0)) do
      visit new_task_path
      fill_in "Title", with: "Stretch every 2 hours"
      click_button "Save"
    end

    task = Task.last
    expect(task.all_day?).to eq(false)
    expect(task.due_at.strftime("%H:%M")).to eq("09:30")
  end
end
