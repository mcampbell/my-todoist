require "rails_helper"

RSpec.describe TasksHelper, type: :helper do
  describe "#format_time" do
    it "omits the year when the time is in the current year" do
      travel_to(Time.zone.local(2030, 1, 1)) do
        expect(helper.format_time(Time.zone.local(2030, 6, 5, 14, 30))).to eq("Jun 5, 2:30 PM")
      end
    end

    it "includes the year when the time is not in the current year" do
      travel_to(Time.zone.local(2026, 1, 1)) do
        expect(helper.format_time(Time.zone.local(2030, 6, 5, 14, 30))).to eq("Jun 5, 2030, 2:30 PM")
      end
    end

    it "returns nil for a nil time" do
      expect(helper.format_time(nil)).to be_nil
    end
  end

  describe "#due_tag" do
    it "omits the year on an all-day task in the current year" do
      travel_to(Time.zone.local(2030, 1, 1)) do
        task = Task.new(title: "t", all_day: true, due_at: Time.zone.local(2030, 6, 5))
        expect(helper.due_tag(task)).to eq("Jun 5")
      end
    end

    it "includes the year on an all-day task not in the current year" do
      travel_to(Time.zone.local(2026, 1, 1)) do
        task = Task.new(title: "t", all_day: true, due_at: Time.zone.local(2030, 6, 5))
        expect(helper.due_tag(task)).to eq("Jun 5, 2030")
      end
    end

    it "includes the year on a timed task not in the current year" do
      travel_to(Time.zone.local(2026, 1, 1)) do
        task = Task.new(title: "t", all_day: false, due_at: Time.zone.local(2030, 6, 5, 14, 30))
        expect(helper.due_tag(task)).to eq("Jun 5, 2030, 2:30 PM")
      end
    end

    it "returns nil when the task has no due_at" do
      expect(helper.due_tag(Task.new(title: "t"))).to be_nil
    end
  end

  describe "#priority_label" do
    it "inverts the stored integer to the p1..p4 input convention" do
      expect([ 3, 2, 1, 0 ].map { |stored| helper.priority_label(stored) })
        .to eq([ 1, 2, 3, 4 ])
    end
  end

  describe "#priority_badge" do
    it "renders a colored tag for p1..p3" do
      task = Task.new(title: "t", priority: 3)
      expect(helper.priority_badge(task)).to include("P1").and include("is-danger")
    end

    it "renders nothing for p4 (stored 0), the baseline priority" do
      task = Task.new(title: "t", priority: 0)
      expect(helper.priority_badge(task)).to be_nil
    end
  end

  describe "#priority_select_options" do
    it "lists p1..p4 in urgent-first order, each mapped to its stored integer" do
      expect(helper.priority_select_options).to eq([ [ "P1", 3 ], [ "P2", 2 ], [ "P3", 1 ], [ "P4", 0 ] ])
    end
  end
end
