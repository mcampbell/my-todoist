require "rails_helper"

RSpec.describe Recurrence do
  describe ".parse" do
    it "returns nil for a blank string" do
      expect(Recurrence.parse(nil)).to be_nil
      expect(Recurrence.parse("")).to be_nil
      expect(Recurrence.parse("   ")).to be_nil
    end

    it "raises InvalidError for a malformed string" do
      expect { Recurrence.parse("every") }.to raise_error(Recurrence::InvalidError)
      expect { Recurrence.parse("every 3 potatoes") }.to raise_error(Recurrence::InvalidError)
      expect { Recurrence.parse("potatoes") }.to raise_error(Recurrence::InvalidError)
    end

    it "parses a plain unit with no count" do
      rule = Recurrence.parse("every day")
      expect(rule).not_to be_nil
      expect(rule).not_to be_rolling
      expect(rule.interval).to eq(1.day)
    end

    it "parses a singular unit" do
      expect(Recurrence.parse("every week")).not_to be_nil
      expect(Recurrence.parse("every month")).not_to be_nil
      expect(Recurrence.parse("every hour")).not_to be_nil
    end

    it "parses a count with a plural unit" do
      rule = Recurrence.parse("every 3 days")
      expect(rule.interval).to eq(3.days)
    end

    it "marks a bang as rolling" do
      expect(Recurrence.parse("every! day")).to be_rolling
      expect(Recurrence.parse("every! 2 weeks")).to be_rolling
    end

    it "parses weekday names and business-day units" do
      expect(Recurrence.parse("every monday")).not_to be_nil
      expect(Recurrence.parse("every saturday")).not_to be_nil
      expect(Recurrence.parse("every weekday")).not_to be_nil
      expect(Recurrence.parse("every workday")).not_to be_nil
    end

    it "normalizes the workday alias to the :weekday unit" do
      expect(Recurrence.parse("every workday").unit).to eq(:weekday)
    end

    it "rejects a zero count" do
      expect { Recurrence.parse("every 0 days") }.to raise_error(Recurrence::InvalidError)
      expect { Recurrence.parse("every! 0 minutes") }.to raise_error(Recurrence::InvalidError)
      expect { Recurrence.parse("every 0 months") }.to raise_error(Recurrence::InvalidError)
    end

    it "accepts case-insensitive input" do
      expect(Recurrence.parse("EVERY 3 DAYS")).not_to be_nil
      expect(Recurrence.parse("Every! Monday")).not_to be_nil
    end

    it "rejects a count on a weekday-name recurrence" do
      expect { Recurrence.parse("every 3 monday") }.to raise_error(Recurrence::InvalidError)
    end
  end

  # Fixed: marches from due_at in intervals until >= now, preserving phase.
  # Rolling: one-shot from now (or the named weekday on/after now).
  describe "#next_from" do
    around do |example|
      travel_to(Time.zone.local(2026, 2, 10, 12, 0, 0)) { example.run } # Tuesday
    end

    describe "fixed (no bang)" do
      it "advances a daily recurrence in whole intervals, never resetting to now" do
        rule = Recurrence.parse("every day")
        result = rule.next_from(due_at: Time.zone.local(2026, 2, 8, 12, 0, 0), now: Time.current)
        expect(result).to eq(Time.zone.local(2026, 2, 10, 12, 0, 0))
      end

      it "advances an N-days recurrence in whole intervals (worked example)" do
        # every 3 days, 8 days overdue -> lands 1 day out, not on completion.
        rule = Recurrence.parse("every 3 days")
        result = rule.next_from(due_at: Time.zone.local(2026, 2, 2, 12, 0, 0), now: Time.current)
        expect(result).to eq(Time.zone.local(2026, 2, 11, 12, 0, 0))
      end

      it "preserves phase for an overdue weekly recurrence (worked example)" do
        # every wednesday, completed on a Saturday, 10 days after the missed Wednesday.
        # due_at is the missed Wednesday (2026-01-28); now is Saturday 2026-02-07.
        rule = Recurrence.parse("every wednesday")
        new_now = Time.zone.local(2026, 2, 7, 12, 0, 0)
        result = rule.next_from(due_at: Time.zone.local(2026, 1, 28, 12, 0, 0), now: new_now)
        expect(result).to eq(Time.zone.local(2026, 2, 11, 12, 0, 0)) # coming Wednesday
      end

      it "advances an N-hours recurrence in whole-hour steps" do
        rule = Recurrence.parse("every 3 hours")
        result = rule.next_from(due_at: Time.zone.local(2026, 2, 10, 8, 0), now: Time.current)
        expect(result).to eq(Time.zone.local(2026, 2, 10, 14, 0))
      end

      it "advances an N-minutes recurrence in whole-minute steps" do
        rule = Recurrence.parse("every 45 minutes")
        result = rule.next_from(due_at: Time.zone.local(2026, 2, 10, 9, 0), now: Time.current)
        expect(result).to eq(Time.zone.local(2026, 2, 10, 12, 0))
      end

      it "leaves an in-the-future due_at at the next interval, not itself" do
        rule = Recurrence.parse("every week")
        result = rule.next_from(due_at: Time.zone.local(2026, 2, 20, 9, 0), now: Time.current)
        expect(result).to eq(Time.zone.local(2026, 2, 27, 9, 0))
      end

      it "advances yearly" do
        rule = Recurrence.parse("every 2 years")
        result = rule.next_from(due_at: Time.zone.local(2020, 1, 1), now: Time.current)
        expect(result).to eq(Time.zone.local(2028, 1, 1))
      end

      it "lands monthly as N months from the 1st, discarding day-of-month" do
        rule = Recurrence.parse("every month")
        result = rule.next_from(due_at: Time.zone.local(2026, 1, 31, 12, 0), now: Time.current)
        expect(result).to eq(Time.zone.local(2026, 3, 1, 12, 0))
      end

      it "lands N-months from the 1st of the anchor's month" do
        rule = Recurrence.parse("every 2 months")
        result = rule.next_from(due_at: Time.zone.local(2026, 1, 15), now: Time.current)
        expect(result).to eq(Time.zone.local(2026, 3, 1, 0, 0))
      end

      it "advances a weekday-name recurrence by one week from the anchor" do
        rule = Recurrence.parse("every monday")
        result = rule.next_from(due_at: Time.zone.local(2026, 2, 9, 9, 0), now: Time.current)
        expect(result).to eq(Time.zone.local(2026, 2, 16, 9, 0))
      end

      it "advances a business-day recurrence to the next business day" do
        rule = Recurrence.parse("every weekday")
        # Due Friday, now Tuesday: steps Mon -> Tue -> the coming Wed (>= now).
        result = rule.next_from(due_at: Time.zone.local(2026, 2, 6, 9, 0), now: Time.current)
        expect(result).to eq(Time.zone.local(2026, 2, 11, 9, 0)) # Wednesday
      end
    end

    describe "rolling (bang)" do
      it "schedules from now for a daily recurrence" do
        rule = Recurrence.parse("every! day")
        result = rule.next_from(due_at: Time.zone.local(2020, 1, 1), now: Time.current)
        expect(result).to eq(1.day.since(Time.current))
      end

      it "schedules from now for an N-hours recurrence" do
        rule = Recurrence.parse("every! 6 hours")
        result = rule.next_from(due_at: Time.zone.local(2020, 1, 1), now: Time.current)
        expect(result).to eq(6.hours.since(Time.current))
      end

      it "schedules from now for a minutes recurrence" do
        rule = Recurrence.parse("every! 10 minutes")
        result = rule.next_from(due_at: Time.zone.local(2020, 1, 1), now: Time.current)
        expect(result).to eq(10.minutes.since(Time.current))
      end

      it "schedules from now for a weekly recurrence" do
        rule = Recurrence.parse("every! week")
        result = rule.next_from(due_at: Time.zone.local(2020, 1, 1), now: Time.current)
        expect(result).to eq(1.week.since(Time.current))
      end

      it "schedules from now for an N-years recurrence" do
        rule = Recurrence.parse("every! 2 years")
        result = rule.next_from(due_at: Time.zone.local(2020, 1, 1), now: Time.current)
        expect(result).to eq(2.years.since(Time.current))
      end

      it "schedules N months from now on the 1st" do
        rule = Recurrence.parse("every! 3 months")
        result = rule.next_from(due_at: Time.zone.local(2020, 1, 1), now: Time.current)
        expect(result).to eq(3.months.since(Time.current).beginning_of_month)
      end

      it "schedules on the 1st of next month for a monthly recurrence" do
        rule = Recurrence.parse("every! month")
        result = rule.next_from(due_at: Time.zone.local(2020, 1, 1), now: Time.current)
        expect(result).to eq(1.month.since(Time.current).beginning_of_month)
      end

      it "reschedules a weekday-name recurrence from the completion date" do
        # Completed Tuesday Feb 10; next Monday is Feb 16.
        rule = Recurrence.parse("every! monday")
        result = rule.next_from(due_at: Time.zone.local(2020, 1, 1), now: Time.current)
        expect(result).to eq(Time.zone.local(2026, 2, 16, 12, 0, 0))
      end

      it "reschedules a business-day recurrence to the next business day" do
        # Completed Friday -> next Monday.
        rule = Recurrence.parse("every! weekday")
        result = rule.next_from(due_at: Time.zone.local(2020, 1, 1), now: Time.zone.local(2026, 2, 6, 9, 0, 0))
        expect(result).to eq(Time.zone.local(2026, 2, 9, 9, 0, 0))
      end
    end
  end
end
