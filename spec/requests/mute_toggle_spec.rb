require "rails_helper"

# The button only renders here; notifications.js flips the per-browser flag
# (no JS test driver, see .okf/decisions/no-js-test-driver.md).
RSpec.describe "Mute toggle", type: :request do
  def mute_button = response.parsed_body.at_css("button[data-mute-toggle]")

  it "shows a non-submitting Mute button on every task list" do
    project = Project.create!(name: "Work")
    [ tasks_path, project_tasks_path(project), today_tasks_path, overdue_tasks_path, upcoming_tasks_path ].each do |path|
      get path
      expect(mute_button).to be_present, "no Mute button on #{path}"
      expect(mute_button.to_h).to include("type" => "button", "aria-pressed" => "false")
    end
  end

  it "leaves the button off Search, Completed, and completed-task details" do
    occurrence = CompletedOccurrence.create!(task_title: "done", priority: 0, completed_at: Time.current)
    [ search_tasks_path, completed_tasks_path, completed_occurrence_path(occurrence) ].each do |path|
      get path
      expect(mute_button).to be_nil, "Mute button on #{path}"
    end
  end
end
