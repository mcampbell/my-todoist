require "rails_helper"

# rack_test driver: button_to renders a real <form> with a hidden _method
# field, so PATCH/DELETE fire without JS. This proves the button wiring that
# request specs (which call the verbs directly) never exercise.
RSpec.describe "Task flow", type: :system do
  before { driven_by(:rack_test) }

  it "completes a task via the Complete button" do
    Task.create!(title: "wire-check-complete")
    visit tasks_path
    click_button "Complete"

    expect(page).not_to have_content("wire-check-complete")
    expect(Task.last).to be_completed
  end

  it "deletes a task via the Delete button" do
    Task.create!(title: "wire-check-delete")
    visit tasks_path
    expect { click_button "Delete" }.to change(Task, :count).by(-1)
  end
end
