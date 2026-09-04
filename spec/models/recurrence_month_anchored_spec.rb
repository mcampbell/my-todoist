require "rails_helper"

# Month-anchored recurrence: "every[!] first <weekday/workday>" with no "in
# <month>" suffix -- an explicit ordinal-one count on a weekday/business-day
# unit is otherwise indistinguishable from no count at all (both step to the
# very next occurrence), so it is reinterpreted as "of the month" instead of
# the weekday-stepping grammar that higher ordinals ("every third monday")
# keep. Reuses MonthDay, walking months instead of years like the
# yearly-anchored grammar does.
RSpec.describe Recurrence, "month-anchored recurrence" do
  describe ".parse" do
    it "reinterprets an explicit ordinal-one weekday count as month-anchored" do
      rule = Recurrence.parse("every first wednesday")
      expect(rule.unit).to eq(:month_anchored)
      expect(rule).not_to be_rolling
    end

    it "marks a bang as rolling" do
      expect(Recurrence.parse("every! first wednesday")).to be_rolling
    end

    it "accepts 1st and bare 1 as equivalent to 'first'" do
      expect(Recurrence.parse("every 1st wednesday").unit).to eq(:month_anchored)
      expect(Recurrence.parse("every 1 wednesday").unit).to eq(:month_anchored)
    end

    it "accepts business-day (weekday/workday) tokens the same way" do
      expect(Recurrence.parse("every first weekday").unit).to eq(:month_anchored)
      expect(Recurrence.parse("every first workday").unit).to eq(:month_anchored)
    end

    it "leaves a higher explicit ordinal as weekday-stepping (unchanged behavior)" do
      rule = Recurrence.parse("every third monday")
      expect(rule.unit).to eq(:monday)
      expect(rule.count).to eq(3)
    end

    it "leaves a bare weekday with no count as plain weekly (unchanged behavior)" do
      rule = Recurrence.parse("every wednesday")
      expect(rule.unit).to eq(:wednesday)
      expect(rule.count).to eq(1)
    end
  end

  describe "#next_from" do
    around do |example|
      travel_to(Time.zone.local(2026, 2, 10, 12, 0, 0)) { example.run } # Tuesday
    end

    it "fixed advances to the same ordinal weekday next month, not the next weekly occurrence" do
      rule = Recurrence.parse("every first wednesday")
      due_at = Time.zone.local(2026, 2, 4, 9, 0, 0) # first Wednesday of Feb 2026
      result = rule.next_from(due_at: due_at, now: due_at)
      expect(result).to eq(Time.zone.local(2026, 3, 4, 9, 0, 0)) # first Wednesday of March, not Feb 11
    end

    it "fixed skips forward through months until now is reached" do
      rule = Recurrence.parse("every first wednesday")
      due_at = Time.zone.local(2026, 2, 4, 9, 0, 0)
      result = rule.next_from(due_at: due_at, now: Time.zone.local(2026, 3, 10, 9, 0, 0)) # after March's slot
      expect(result).to eq(Time.zone.local(2026, 4, 1, 9, 0, 0)) # April 1 2026 is a Wednesday
    end

    it "rolling schedules the next unpassed month's slot at the completion clock time" do
      rule = Recurrence.parse("every! first wednesday")
      result = rule.next_from(due_at: Time.zone.local(2025, 1, 1, 9, 0, 0), now: Time.zone.local(2026, 2, 20, 15, 30, 0))
      expect(result).to eq(Time.zone.local(2026, 3, 4, 15, 30, 0)) # Feb's slot (the 4th) already passed
    end

    it "supports business-day (weekday) tokens the same way" do
      rule = Recurrence.parse("every first weekday")
      due_at = Time.zone.local(2026, 2, 2, 9, 0, 0) # first business day of Feb 2026 (Monday)
      result = rule.next_from(due_at: due_at, now: due_at)
      expect(result).to eq(Time.zone.local(2026, 3, 2, 9, 0, 0)) # first business day of March (Monday)
    end
  end

  describe "#first_occurrence" do
    it "resolves the ordinal weekday of the month containing on_or_after, or the next month if already past" do
      rule = Recurrence.parse("every first wednesday")
      expect(rule.first_occurrence(on_or_after: Date.new(2026, 2, 1))).to eq(Date.new(2026, 2, 4))
      expect(rule.first_occurrence(on_or_after: Date.new(2026, 2, 10))).to eq(Date.new(2026, 3, 4))
    end
  end
end
