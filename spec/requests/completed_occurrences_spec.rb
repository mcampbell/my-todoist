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

    it "renders an all-day occurrence's due date without a phantom midnight time" do
      travel_to(Time.zone.local(2030, 1, 1)) do
        occurrence = CompletedOccurrence.create!(
          task_title: "All day", priority: 0,
          due_at: Time.zone.local(2030, 1, 1).beginning_of_day, all_day: true,
          completed_at: Time.zone.local(2030, 1, 1, 9, 15)
        )

        get completed_occurrence_path(occurrence)

        expect(response).to have_http_status(:ok)
        due_text = Nokogiri::HTML(response.body).at_xpath("//tr[th='Due']/td").text.strip
        expect(due_text).to eq("Jan 1")
      end
    end

    it "includes the year in the Due and Completed fields when they aren't the current year" do
      travel_to(Time.zone.local(2026, 1, 1)) do
        occurrence = CompletedOccurrence.create!(
          task_title: "Old task", priority: 0,
          due_at: Time.zone.local(2030, 1, 1, 9, 15), all_day: false,
          completed_at: Time.zone.local(2030, 1, 1, 9, 20)
        )

        get completed_occurrence_path(occurrence)

        due_text = Nokogiri::HTML(response.body).at_xpath("//tr[th='Due']/td").text.strip
        completed_text = Nokogiri::HTML(response.body).at_xpath("//tr[th='Completed']/td").text.strip
        expect(due_text).to eq("Jan 1, 2030, 9:15 AM")
        expect(completed_text).to eq("Jan 1, 2030, 9:20 AM")
      end
    end

    it "renders the priority row in the p1..p4 display convention" do
      urgent = CompletedOccurrence.create!(
        task_title: "Urgent occurrence", priority: 3,
        completed_at: Time.current
      )

      get completed_occurrence_path(urgent)

      priority_text = Nokogiri::HTML(response.body).at_xpath("//tr[th='Priority']/td").text.strip
      expect(priority_text).to eq("P1")

      baseline = CompletedOccurrence.create!(
        task_title: "Baseline occurrence", priority: 0,
        completed_at: Time.current
      )

      get completed_occurrence_path(baseline)

      priority_text = Nokogiri::HTML(response.body).at_xpath("//tr[th='Priority']/td").text.strip
      expect(priority_text).to eq("P4")
    end
  end
end
