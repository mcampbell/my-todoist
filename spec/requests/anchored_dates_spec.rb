require "rails_helper"

RSpec.describe "Anchored dates", type: :request do
  around do |example|
    travel_to(Time.zone.local(2026, 1, 15, 9, 0, 0)) { example.run }
  end

  it "rejects an impossible one-shot anchored date, creating nothing" do
    expect {
      post tasks_path, params: { task: { title: "party 6th monday in feb" } }
    }.not_to change(Task, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to match(/6th monday in feb/i)
  end

  it "creates a yearly-anchored recurrence seeded to its first occurrence" do
    post tasks_path, params: { task: { title: "plan every! first monday in jun" } }
    task = Task.last
    expect(task.recurrence).to eq("every! first monday in jun")
    expect(task.due_at.to_date).to eq(Date.new(2026, 6, 1))
  end
end
