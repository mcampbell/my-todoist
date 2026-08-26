require "rails_helper"

# Yearly-anchored recurrence: "every[!] {first/last/nth} {weekday/workday/day}
# in <month>" -- once a year on that calendar slot. Reuses MonthDay/CalendarTerms
# with the one-shot PointInTime grammar. Rejected at parse (not skipped at
# runtime) when the ordinal is not guaranteed in every year's month.
RSpec.describe Recurrence, "anchored yearly recurrence" do
  describe ".parse" do
    it "parses a fixed anchored recurrence" do
      rule = Recurrence.parse("every first monday in june")
      expect(rule.unit).to eq(:anchored)
      expect(rule).not_to be_rolling
    end

    it "marks a bang as rolling" do
      expect(Recurrence.parse("every! first monday in june")).to be_rolling
    end

    it "accepts last, business days, numeric ordinals, and mixed case" do
      expect(Recurrence.parse("every last friday in march").unit).to eq(:anchored)
      expect(Recurrence.parse("every last workday in december").unit).to eq(:anchored)
      expect(Recurrence.parse("EVERY 4th Monday in FEB").unit).to eq(:anchored)
    end

    it "rejects an ordinal not guaranteed in every year's month" do
      # Feb has only four guaranteed Mondays; a 5th exists only some years.
      expect { Recurrence.parse("every 5th monday in feb") }.to raise_error(Recurrence::InvalidError)
      expect { Recurrence.parse("every 6th monday in june") }.to raise_error(Recurrence::InvalidError)
      # January has 21 guaranteed business days, not 22.
      expect { Recurrence.parse("every 22nd workday in january") }.to raise_error(Recurrence::InvalidError)
    end

    it "accepts the guaranteed boundary ordinals" do
      expect(Recurrence.parse("every 4th monday in feb").unit).to eq(:anchored)
      expect(Recurrence.parse("every 21st workday in january").unit).to eq(:anchored)
    end

    it "rejects a zero ordinal" do
      expect { Recurrence.parse("every 0th monday in march") }.to raise_error(Recurrence::InvalidError)
    end

    it "accepts the anchored form without the optional 'in'" do
      expect(Recurrence.parse("every first monday june").unit).to eq(:anchored)
    end
  end

  describe "#next_from" do
    around do |example|
      travel_to(Time.zone.local(2026, 2, 10, 12, 0, 0)) { example.run } # Tuesday
    end

    it "rolling schedules this year's slot from now, at the completion clock time" do
      rule = Recurrence.parse("every! first monday in june")
      result = rule.next_from(due_at: Time.zone.local(2025, 6, 2, 9, 0, 0), now: Time.current)
      expect(result).to eq(Time.zone.local(2026, 6, 1, 12, 0, 0)) # June 1 2026 is a Monday
    end

    it "fixed lands this year's slot preserving the original due clock time" do
      rule = Recurrence.parse("every first monday in june")
      result = rule.next_from(due_at: Time.zone.local(2026, 1, 1, 9, 0, 0), now: Time.current)
      expect(result).to eq(Time.zone.local(2026, 6, 1, 9, 0, 0))
    end

    it "fixed rolls a year after the slot is completed on time" do
      rule = Recurrence.parse("every first monday in june")
      due = Time.zone.local(2026, 6, 1, 9, 0, 0)
      result = rule.next_from(due_at: due, now: Time.zone.local(2026, 6, 1, 15, 0, 0))
      expect(result).to eq(Time.zone.local(2027, 6, 7, 9, 0, 0)) # June 2027 1st Monday is the 7th
    end

    it "resolves last-weekday and last-business-day slots" do
      friday = Recurrence.parse("every! last friday in march")
      expect(friday.next_from(due_at: Time.current, now: Time.current))
        .to eq(Time.zone.local(2026, 3, 27, 12, 0, 0))

      workday = Recurrence.parse("every! last workday in december")
      expect(workday.next_from(due_at: Time.current, now: Time.current))
        .to eq(Time.zone.local(2026, 12, 31, 12, 0, 0))
    end
  end
end
