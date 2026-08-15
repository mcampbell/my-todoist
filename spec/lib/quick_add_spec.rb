require "rails_helper"

RSpec.describe QuickAdd, type: :model do
  describe ".parse" do
    it "maps p1 to priority 3" do
      expect(described_class.parse("buy milk p1")).to include(title: "buy milk", priority: 3)
    end

    it "maps p2 to priority 2" do
      expect(described_class.parse("buy milk p2")).to include(title: "buy milk", priority: 2)
    end

    it "maps p3 to priority 1" do
      expect(described_class.parse("buy milk p3")).to include(title: "buy milk", priority: 1)
    end

    it "maps p4 to priority 0" do
      expect(described_class.parse("buy milk p4")).to include(title: "buy milk", priority: 0)
    end

    it "strips the token wherever it appears in the text" do
      expect(described_class.parse("p2 buy milk")).to include(title: "buy milk", priority: 2)
      expect(described_class.parse("buy p2 milk")).to include(title: "buy milk", priority: 2)
    end

    it "leaves priority unset when no token is present" do
      expect(described_class.parse("buy milk")).to include(title: "buy milk", priority: nil)
    end

    it "leaves malformed pN tokens as literal title text" do
      expect(described_class.parse("p5 buy p0 milk")).to include(title: "p5 buy p0 milk", priority: nil)
    end

    it "strips only the first valid pN token" do
      expect(described_class.parse("p2 p4 milk")).to include(title: "p4 milk", priority: 2)
    end

    it "does not treat pN inside a larger word as a token" do
      expect(described_class.parse("check apple1")).to include(title: "check apple1", priority: nil)
    end

    it "collapses leftover whitespace around the stripped token" do
      expect(described_class.parse("buy  p2   milk")).to include(title: "buy milk", priority: 2)
    end

    it "returns nil due fields when no date or time token is present" do
      expect(described_class.parse("buy milk")).to eq(
        title: "buy milk", priority: nil, due_date: nil, due_time: nil
      )
    end
  end

  describe "date/time tokens" do
    def parse_at(time, text)
      travel_to(time) { described_class.parse(text) }
    end

    it "parses a timed date phrase and strips it from the title" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist wed 3pm")).to include(
        title: "Call dentist", priority: nil, due_date: "2026-08-19", due_time: "15:00"
      )
    end

    it "honors an explicit date over the bare-time roll" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 16, 0, 0), "Call dentist wed noon")).to include(
        title: "Call dentist", due_date: "2026-08-19", due_time: "12:00"
      )
    end

    it "keeps a bare date phrase as all-day (no time leak)" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist tomorrow")).to include(
        title: "Call dentist", due_date: "2026-08-16", due_time: nil
      )
    end

    it "parses next monday as an all-day one-off" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist next monday")).to include(
        title: "Call dentist", due_date: "2026-08-17", due_time: nil
      )
    end

    it "parses a month-day phrase as all-day" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist aug 20")).to include(
        title: "Call dentist", due_date: "2026-08-20", due_time: nil
      )
    end

    it "keeps a bare digit in the title with no due date" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist 3")).to include(
        title: "Call dentist 3", due_date: nil, due_time: nil
      )
    end

    it "dates a bare time word today when it is still ahead" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist noon")).to include(
        title: "Call dentist", due_date: "2026-08-15", due_time: "12:00"
      )
    end

    it "rolls a bare time word to tomorrow when now is after the time" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 16, 0, 0), "Call dentist noon")).to include(
        title: "Call dentist", due_date: "2026-08-16", due_time: "12:00"
      )
    end

    it "rolls a bare time word to tomorrow when now equals the time" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 12, 0, 0), "Call dentist noon")).to include(
        title: "Call dentist", due_date: "2026-08-16", due_time: "12:00"
      )
    end

    it "dates a bare digit-time today when still ahead" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist 3pm")).to include(
        title: "Call dentist", due_date: "2026-08-15", due_time: "15:00"
      )
    end

    it "rolls a bare digit-time to tomorrow when passed" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 16, 0, 0), "Call dentist 3pm")).to include(
        title: "Call dentist", due_date: "2026-08-16", due_time: "15:00"
      )
    end

    it "parses a space-separated time (3 pm)" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist 3 pm")).to include(
        title: "Call dentist", due_date: "2026-08-15", due_time: "15:00"
      )
    end

    it "parses a 24-hour time" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 16, 0, 0), "Call dentist 15:00")).to include(
        title: "Call dentist", due_date: "2026-08-16", due_time: "15:00"
      )
    end

    it "parses a word-time form (3 o'clock)" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist 3 o'clock")).to include(
        title: "Call dentist", due_date: "2026-08-15", due_time: "15:00"
      )
    end

    it "combines priority and date tokens in one submission" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist p2 wed 3pm")).to include(
        title: "Call dentist", priority: 2, due_date: "2026-08-19", due_time: "15:00"
      )
    end
  end

  describe "recurrence rejection" do
    it "rejects every <weekday> phrases" do
      expect { described_class.parse("Call dentist every wednesday") }
        .to raise_error(QuickAdd::RecurrenceNotSupportedError, /Recurrence not supported yet/)
    end

    it "rejects every! with a count and unit" do
      expect { described_class.parse("water plants every! 10 minutes") }
        .to raise_error(QuickAdd::RecurrenceNotSupportedError, /Recurrence not supported yet/)
    end

    it "rejects every <unit> phrases" do
      expect { described_class.parse("stretch every day") }
        .to raise_error(QuickAdd::RecurrenceNotSupportedError, /Recurrence not supported yet/)
    end

    it "rejects every N <unit> phrases" do
      expect { described_class.parse("walk every 3 days") }
        .to raise_error(QuickAdd::RecurrenceNotSupportedError, /Recurrence not supported yet/)
    end

    it "rejects every weekday" do
      expect { described_class.parse("sync every weekday") }
        .to raise_error(QuickAdd::RecurrenceNotSupportedError, /Recurrence not supported yet/)
    end

    it "rejects the bare weekdays shorthand" do
      expect { described_class.parse("sync weekdays") }
        .to raise_error(QuickAdd::RecurrenceNotSupportedError, /Recurrence not supported yet/)
    end

    it "rejects the bare workday shorthand" do
      expect { described_class.parse("sync workday") }
        .to raise_error(QuickAdd::RecurrenceNotSupportedError, /Recurrence not supported yet/)
    end

    it "rejects recurrence phrases case-insensitively" do
      expect { described_class.parse("Every Wednesday") }
        .to raise_error(QuickAdd::RecurrenceNotSupportedError, /Recurrence not supported yet/)
    end

    it "does not reject a title that merely contains every" do
      expect(described_class.parse("clean every room")).to include(
        title: "clean every room", priority: nil, due_date: nil, due_time: nil
      )
    end
  end
end
