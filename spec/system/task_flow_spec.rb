require "rails_helper"

# rack_test driver: no JS needed. Every control is a button_to / link_to
# (a real form or anchor), so each one submits or navigates without a browser.
RSpec.describe "Task flow", type: :system do
  before { driven_by(:rack_test) }

  it "completes a task via the checkbox control" do
    task = Task.create!(title: "complete-me")
    visit tasks_path
    find("button[aria-label='Complete #{task.title}']").click

    expect(task.reload).to be_completed
    expect(page).to have_no_content("complete-me")
  end

  it "deletes a task via the trash icon button" do
    task = Task.create!(title: "delete-me")
    visit tasks_path
    expect {
      find("button[aria-label='Delete #{task.title}']").click
    }.to change(Task, :count).by(-1)
  end

  it "navigates to the edit page via the pencil icon" do
    task = Task.create!(title: "edit-me")
    visit tasks_path
    find("a[aria-label='Edit #{task.title}']").click
    expect(page).to have_current_path(edit_task_path(task))
  end

  it "renders the row controls as svg icons, not text" do
    task = Task.create!(title: "icon-check")
    visit tasks_path
    expect(page).to have_css("button[aria-label='Complete #{task.title}'] svg")
    expect(page).to have_css("a[aria-label='Edit #{task.title}'] svg")
    expect(page).to have_css("button[aria-label='Delete #{task.title}'] svg")
    expect(find("a[aria-label='Edit #{task.title}']")).to have_no_text("Edit")
  end
end
