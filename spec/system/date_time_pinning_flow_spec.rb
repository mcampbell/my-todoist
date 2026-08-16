require "rails_helper"

# rack_test driver: no JS needed, matches spec/system/task_flow_spec.rb.
RSpec.describe "Date/time pinning", type: :system do
  before { driven_by(:rack_test) }

  it "pins a bare date word to an all-day due date" do
    travel_to(Time.zone.local(2026, 8, 17, 10, 0, 0)) do
      visit new_task_path
      fill_in "Title", with: "Renew passport tomorrow"
      click_button "Save"
    end

    task = Task.last
    expect(task.title).to eq("Renew passport")
    expect(task.due_at).to eq(Time.zone.local(2026, 8, 18).beginning_of_day)
    expect(task.all_day?).to eq(true)
    expect(page).to have_content("Aug 18")
  end

  it "pins a bare time word to a timed due date, rolling to the next occurrence" do
    travel_to(Time.zone.local(2026, 8, 17, 13, 0, 0)) do
      visit new_task_path
      fill_in "Title", with: "Take medicine noon"
      click_button "Save"
    end

    task = Task.last
    expect(task.all_day?).to eq(false)
    expect(task.due_at).to eq(Time.zone.local(2026, 8, 18, 12, 0, 0))
    expect(page).to have_content("12:00 PM")
  end

  it "pins a day-scale 'in X unit' offset to an all-day due date, with no time-of-day" do
    travel_to(Time.zone.local(2026, 8, 17, 10, 0, 0)) do
      visit new_task_path
      fill_in "Title", with: "Call mom in 3 days"
      click_button "Save"
    end

    task = Task.last
    expect(task.title).to eq("Call mom")
    expect(task.due_at).to eq(Time.zone.local(2026, 8, 20).beginning_of_day)
    expect(task.all_day?).to eq(true)
    expect(page).to have_content("Aug 20")
  end

  it "pins an hour-scale 'in X unit' offset to an exact timed due date" do
    travel_to(Time.zone.local(2026, 8, 17, 10, 15, 0)) do
      visit new_task_path
      fill_in "Title", with: "Check oven in 2 hours"
      click_button "Save"
    end

    task = Task.last
    expect(task.all_day?).to eq(false)
    expect(task.due_at).to eq(Time.zone.local(2026, 8, 17, 12, 15, 0))
    expect(page).to have_content("12:15 PM")
  end

  it "resolves the 'a'/'an' count to 1 for an 'in X unit' offset" do
    travel_to(Time.zone.local(2026, 8, 17, 10, 0, 0)) do
      visit new_task_path
      fill_in "Title", with: "Follow up in a week"
      click_button "Save"
    end

    task = Task.last
    expect(task.due_at).to eq(Time.zone.local(2026, 8, 24).beginning_of_day)
  end
end
