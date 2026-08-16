require "rails_helper"

# rack_test driver: no JS engine, so this cannot execute app/javascript/notifications.js
# itself (no toast rendering, no beep, no dismiss click). It instead verifies the two
# things that JS depends on: the due_since.json contract it polls, and the static
# #toast-container markup it renders into.
RSpec.describe "Notifications", type: :system do
  before { driven_by(:rack_test) }

  it "serves only timed tasks that became due within the polling window" do
    travel_to(Time.zone.local(2026, 8, 17, 12, 0, 0)) do
      due_in_window = Task.create!(title: "Standup", due_date: "2026-08-17", due_time: "11:45")
      Task.create!(title: "Too early", due_date: "2026-08-17", due_time: "11:00")
      Task.create!(title: "All day errand", due_date: "2026-08-17")

      since = 30.minutes.ago.iso8601
      visit due_since_tasks_path(format: :json, since: since)

      body = JSON.parse(page.body)
      expect(body["tasks"].map { |t| t["id"] }).to eq([ due_in_window.id ])
      expect(body["tasks"].first["title"]).to eq("Standup")
      expect(body).to have_key("now")
    end
  end

  it "rejects a non-ISO8601 since param with 400" do
    visit due_since_tasks_path(format: :json, since: "not-a-date")

    expect(page.status_code).to eq(400)
    expect(JSON.parse(page.body)).to eq({ "error" => "since must be ISO8601" })
  end

  it "renders the toast container the notification poller mounts into" do
    visit tasks_path

    expect(page).to have_css("#toast-container", visible: :all)
  end
end
