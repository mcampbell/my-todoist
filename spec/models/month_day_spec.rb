require "rails_helper"

# Pure calendar math shared by the point-in-time (one-shot) and anchored
# (recurring) grammars. Anchors below are hand-verified against a real
# calendar so the expectations don't just echo the implementation.
RSpec.describe MonthDay do
  describe ".nth_of" do
    it "finds the nth named weekday of a month" do
      # Aug 2026: Aug 1 is a Saturday, so the first Monday is Aug 3.
      expect(MonthDay.nth_of(2026, 8, 1, :monday)).to eq(Date.new(2026, 8, 3))
      expect(MonthDay.nth_of(2026, 8, 2, :monday)).to eq(Date.new(2026, 8, 10))
    end

    it "finds the last named weekday of a month" do
      # Mar 2026: last Friday is Mar 27 (Mar 31 is a Tuesday).
      expect(MonthDay.nth_of(2026, 3, :last, :friday)).to eq(Date.new(2026, 3, 27))
    end

    it "returns nil when the nth named weekday does not exist" do
      # Feb 2027 has exactly four Mondays (1, 8, 15, 22).
      expect(MonthDay.nth_of(2027, 2, 4, :monday)).to eq(Date.new(2027, 2, 22))
      expect(MonthDay.nth_of(2027, 2, 5, :monday)).to be_nil
      expect(MonthDay.nth_of(2027, 2, 6, :monday)).to be_nil
    end

    it "finds the nth and last business day of a month" do
      # Dec 2026: Dec 31 is a Thursday, so the last business day is Dec 31.
      expect(MonthDay.nth_of(2026, 12, :last, :business)).to eq(Date.new(2026, 12, 31))
      # Aug 2026: Aug 1 Sat, Aug 2 Sun, so the first business day is Aug 3.
      expect(MonthDay.nth_of(2026, 8, 1, :business)).to eq(Date.new(2026, 8, 3))
    end

    it "returns nil for a business-day ordinal past the month's business days" do
      # Feb 2027 (28 days, starts Monday) has 20 business days.
      expect(MonthDay.nth_of(2027, 2, 20, :business)).to eq(Date.new(2027, 2, 26))
      expect(MonthDay.nth_of(2027, 2, 21, :business)).to be_nil
    end

    it "returns nil for a zero or negative ordinal" do
      expect(MonthDay.nth_of(2026, 3, 0, :monday)).to be_nil
    end
  end

  describe ".guaranteed_min" do
    it "guarantees four of any named weekday in any month" do
      (1..12).each do |month|
        %i[monday tuesday wednesday thursday friday saturday sunday].each do |day|
          expect(MonthDay.guaranteed_min(month, day)).to eq(4)
        end
      end
    end

    it "guarantees 20 business days in February and 30-day months, 21 in 31-day months" do
      expect(MonthDay.guaranteed_min(2, :business)).to eq(20)   # Feb
      expect(MonthDay.guaranteed_min(4, :business)).to eq(20)   # 30-day
      expect(MonthDay.guaranteed_min(9, :business)).to eq(20)   # 30-day
      expect(MonthDay.guaranteed_min(1, :business)).to eq(21)   # 31-day
      expect(MonthDay.guaranteed_min(12, :business)).to eq(21)  # 31-day
    end
  end
end
