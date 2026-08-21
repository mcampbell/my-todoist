require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#seconds_until_midnight" do
    it "counts the whole seconds from now to the next local midnight" do
      now = Time.zone.local(2030, 3, 4, 14, 5) # 9h55m before midnight
      expect(helper.seconds_until_midnight(now)).to eq(9 * 3600 + 55 * 60)
    end

    it "returns a small count just before midnight" do
      now = Time.zone.local(2030, 3, 4, 23, 59, 59)
      expect(helper.seconds_until_midnight(now)).to eq(1)
    end

    it "rolls over month and year ends via the next calendar day" do
      now = Time.zone.local(2030, 12, 31, 23, 0)
      expect(helper.seconds_until_midnight(now)).to eq(3600)
    end
  end
end
