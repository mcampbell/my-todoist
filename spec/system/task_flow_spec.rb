require "rails_helper"

# rack_test driver: no JS. The complete checkbox submits via an inline
# onchange handler, so its round-trip is proven by request specs
# (PATCH /tasks/:id/complete); here we assert the checkbox is wired to the
# complete action. The delete icon button is button_to (a real form), so it
# fires without JS and we exercise it directly.
RSpec.describe "Task flow", type: :system do
  before { driven_by(:rack_test) }

  it "wires the left checkbox to the complete action" do
    task = Task.create!(title: "wire-check-complete")
    visit tasks_path
    expect(page).to have_css(
      "form[action='#{complete_task_path(task)}'] input[type='checkbox']"
    )
  end

  it "deletes a task via the trash icon button" do
    task = Task.create!(title: "wire-check-delete")
    visit tasks_path
    expect {
      find("button[aria-label='Delete #{task.title}']").click
    }.to change(Task, :count).by(-1)
  end

  it "navigates to the edit page via the pencil icon" do
    task = Task.create!(title: "wire-check-edit")
    visit tasks_path
    find("a[aria-label='Edit #{task.title}']").click
    expect(page).to have_current_path(edit_task_path(task))
  end

  it "renders edit and delete as svg icons, not text" do
    task = Task.create!(title: "icon-check")
    visit tasks_path
    expect(page).to have_css("a[aria-label='Edit #{task.title}'] svg")
    expect(page).to have_css("button[aria-label='Delete #{task.title}'] svg")
    expect(find("a[aria-label='Edit #{task.title}']")).to have_no_text("Edit")
  end

  it "keeps edit and delete on one line (delete form is inline-block)" do
    task = Task.create!(title: "layout-check")
    visit tasks_path
    expect(page).to have_css(
      "form.is-inline-block button[aria-label='Delete #{task.title}']"
    )
  end
end
