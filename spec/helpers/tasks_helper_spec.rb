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

  describe "#priority_label" do
    it "inverts the stored integer to the p1..p4 input convention" do
      expect([ 3, 2, 1, 0 ].map { |stored| helper.priority_label(stored) })
        .to eq([ 1, 2, 3, 4 ])
    end
  end

  describe "#priority_badge" do
    it "renders p1 (stored 3) as a danger P1 tag" do
      expect(helper.priority_badge(Task.new(priority: 3)))
        .to eq('<span class="tag is-danger">P1</span>')
    end

    it "renders p2 (stored 2) as a warning P2 tag" do
      expect(helper.priority_badge(Task.new(priority: 2)))
        .to eq('<span class="tag is-warning">P2</span>')
    end

    it "renders p3 (stored 1) as an info P3 tag" do
      expect(helper.priority_badge(Task.new(priority: 1)))
        .to eq('<span class="tag is-info">P3</span>')
    end

    it "renders no badge for p4 (stored 0, baseline)" do
      expect(helper.priority_badge(Task.new(priority: 0))).to be_nil
    end
  end

  describe "#priority_select_options" do
    it "offers p1..p4 labels mapped to stored integers, urgent first" do
      expect(helper.priority_select_options)
        .to eq([ [ "P1", 3 ], [ "P2", 2 ], [ "P3", 1 ], [ "P4", 0 ] ])
    end
  end
end
