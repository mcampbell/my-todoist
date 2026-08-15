require "rails_helper"

RSpec.describe "CompletedOccurrences", type: :request do
  describe "GET /completed_occurrences/:id" do
    it "renders the snapshot" do
      occurrence = CompletedOccurrence.create!(
        task_title: "Water plants", project_name: "Home", priority: 2,
        label_names: "chore, urgent", due_at: Time.zone.local(2030, 1, 1, 9, 0),
        completed_at: Time.current
      )

      get completed_occurrence_path(occurrence)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Water plants")
      expect(response.body).to include("Home")
      expect(response.body).to include("chore, urgent")
    end
  end
end
