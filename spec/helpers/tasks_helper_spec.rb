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
end
