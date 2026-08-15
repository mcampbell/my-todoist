require "rails_helper"

RSpec.describe TasksHelper, type: :helper do
  describe "#format_time" do
    it "formats a time as month, day, hour, minute, meridiem" do
      time = Time.zone.local(2030, 3, 4, 14, 5)
      expect(helper.format_time(time)).to eq("Mar 4, 2:05 PM")
    end

    it "returns nil for a nil time" do
      expect(helper.format_time(nil)).to be_nil
    end
  end

  describe "#due_tag" do
    it "renders only the date for an all-day task (no time)" do
      task = Task.new(due_at: Time.zone.local(2030, 6, 5).beginning_of_day, all_day: true)
      expect(helper.due_tag(task)).to eq("Jun 5")
    end

    it "renders the date and time for a timed task" do
      task = Task.new(due_at: Time.zone.local(2030, 6, 5, 14, 30), all_day: false)
      expect(helper.due_tag(task)).to eq("Jun 5, 2:30 PM")
    end

    it "returns nil when there is no due date" do
      expect(helper.due_tag(Task.new)).to be_nil
    end
  end
end
