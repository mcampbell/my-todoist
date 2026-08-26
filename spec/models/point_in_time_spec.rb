require "rails_helper"

# One-shot anchored dates: "{first/last/nth} {weekday/workday/day} [in] <month>
# [[at] <time>]". Non-recurring. Frozen "now" is 2026-08-26 (Wednesday)
# unless an example overrides it.
RSpec.describe PointInTime do
  def parse_at(now, text)
    travel_to(now) { described_class.parse(text) }
  end

  let(:now) { Time.zone.local(2026, 8, 26, 9, 0, 0) }

  describe ".parse" do
    it "returns nil when the text has no anchored-date shape" do
      expect(described_class.parse("buy milk")).to be_nil
      expect(described_class.parse("call mum on monday")).to be_nil # no month
    end

    it "resolves the nth weekday of an upcoming month (all-day)" do
      result = parse_at(now, "first monday in september")
      expect(result.date).to eq(Date.new(2026, 9, 7)) # Sep 2026: Sep 1 Tue, 1st Mon Sep 7
      expect(result.time).to be_nil
    end

    it "rolls to next year when this year's occurrence has already passed" do
      # Aug 2026 first Monday is Aug 3 (past on the 26th) -> next August.
      result = parse_at(now, "first monday in august")
      expect(result.date).to eq(Date.new(2027, 8, 2))
    end

    it "resolves last weekday of a month" do
      result = parse_at(now, "last friday in march") # March past -> 2027
      expect(result.date).to eq(Date.new(2027, 3, 26))
    end

    it "resolves the nth business day via weekday/workday" do
      result = parse_at(now, "first workday in september at 9am")
      expect(result.date).to eq(Date.new(2026, 9, 1)) # Sep 1 2026 is a Tuesday
      expect(result.time).to eq("09:00")
    end

    it "accepts an explicit time with and without 'at' and 24h form" do
      expect(parse_at(now, "second tuesday in october at 3pm").time).to eq("15:00")
      expect(parse_at(now, "second tuesday in october 15:30").time).to eq("15:30")
    end

    it "accepts numeric ordinals and abbreviated months" do
      result = parse_at(now, "2nd wednesday in dec")
      expect(result.date).to eq(Date.new(2026, 12, 9)) # Dec 2026: Dec 1 Tue, 2nd Wed Dec 9
    end

    it "raises for an ordinal that never exists" do
      expect { parse_at(now, "6th monday in feb") }
        .to raise_error(described_class::InvalidError, /6th monday in feb/i)
    end

    it "raises when the nth day is absent that specific year (no year scan)" do
      # Feb 2027 has only four Mondays; we do NOT scan to a later February.
      expect { parse_at(now, "5th monday in feb") }
        .to raise_error(described_class::InvalidError, /5th monday in feb/i)
    end

    it "rolls a full year when the target is today but the time has passed" do
      # Aug 31 2026 is the last Monday of August; at 10:00 the 9am slot is gone.
      passed = Time.zone.local(2026, 8, 31, 10, 0, 0)
      result = parse_at(passed, "last monday in august at 9am")
      expect(result.date).to eq(Date.new(2027, 8, 30))
      expect(result.time).to eq("09:00")
    end

    it "reports the matched span so the caller can strip it" do
      result = parse_at(now, "first monday in september")
      expect(result.range).to eq(0...25)
    end

    it "raises for a zero ordinal" do
      expect { parse_at(now, "0th monday in march") }
        .to raise_error(described_class::InvalidError, /0th monday in march/i)
    end
  end
end
