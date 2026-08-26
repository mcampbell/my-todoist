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
        title: "buy milk", priority: nil, due_date: nil, due_time: nil, project_name: nil, recurrence: nil,
        due_error: nil
      )
    end
  end

  describe "project tokens" do
    it "extracts a #project token and strips it from the title" do
      expect(described_class.parse("Call #Work dentist")).to include(
        title: "Call dentist", project_name: "Work"
      )
    end

    it "extracts a token at the start of the text" do
      expect(described_class.parse("#Work call")).to include(title: "call", project_name: "Work")
    end

    it "keeps the raw token casing (matching is case-insensitive at the DB)" do
      expect(described_class.parse("Call #work dentist")).to include(
        title: "Call dentist", project_name: "work"
      )
    end

    it "does not treat # inside a word as a token" do
      expect(described_class.parse("check hash#tag")).to include(
        title: "check hash#tag", project_name: nil
      )
    end

    it "keeps a bare # in the title" do
      expect(described_class.parse("Call # dentist")).to include(
        title: "Call # dentist", project_name: nil
      )
    end

    it "strips trailing punctuation from the token" do
      expect(described_class.parse("Call #Work. dentist")).to include(
        title: "Call dentist", project_name: "Work"
      )
    end

    it "takes only the first project token" do
      expect(described_class.parse("Call #Work then #Home")).to include(
        title: "Call then #Home", project_name: "Work"
      )
    end

    it "combines project with priority and date tokens in one submission" do
      travel_to(Time.zone.local(2026, 8, 15, 10, 0, 0)) do
        expect(described_class.parse("Call #Health dentist p2 wed 3pm")).to include(
          title: "Call dentist", project_name: "Health", priority: 2,
          due_date: "2026-08-19", due_time: "15:00"
        )
      end
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

    it "parses next weekday as an all-day one-off (not recurrence)" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist next weekday")).to include(
        title: "Call dentist", due_date: "2026-08-17", due_time: nil
      )
    end

    it "parses next workday as an all-day one-off, translating to Chronic's 'weekday'" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist next workday")).to include(
        title: "Call dentist", due_date: "2026-08-17", due_time: nil
      )
    end

    it "parses last workday as an all-day one-off, not recurrence" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist last workday")).to include(
        title: "Call dentist", due_date: "2026-08-14", due_time: nil
      )
    end

    it "parses last weekday as an all-day one-off, not recurrence" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist last weekday")).to include(
        title: "Call dentist", due_date: "2026-08-14", due_time: nil
      )
    end

    it "extracts bare 'workday' as recurrence shorthand (not preceded by next)" do
      expect(described_class.parse("Take out trash workday")).to include(
        title: "Take out trash", recurrence: "every weekday"
      )
    end

    it "extracts bare 'weekdays' as recurrence shorthand (not preceded by next)" do
      expect(described_class.parse("Take out trash weekdays")).to include(
        title: "Take out trash", recurrence: "every weekday"
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

    it "parses a compact dash date with year (15-aug-2026)" do
      expect(parse_at(Time.zone.local(2026, 8, 1, 10, 0, 0), "Call dentist 15-aug-2026")).to include(
        title: "Call dentist", due_date: "2026-08-15", due_time: nil
      )
    end

    it "parses a compact dash date without a year, defaulting to current year (15-aug)" do
      expect(parse_at(Time.zone.local(2026, 8, 1, 10, 0, 0), "Call dentist 15-aug")).to include(
        title: "Call dentist", due_date: "2026-08-15", due_time: nil
      )
    end

    it "parses a compact slash date (15/aug/2026)" do
      expect(parse_at(Time.zone.local(2026, 8, 1, 10, 0, 0), "Call dentist 15/aug/2026")).to include(
        title: "Call dentist", due_date: "2026-08-15", due_time: nil
      )
    end

    it "parses a compact dash date placed mid-title, stripping cleanly" do
      expect(parse_at(Time.zone.local(2026, 8, 1, 10, 0, 0), "Call dentist 15-aug-2026 about braces")).to include(
        title: "Call dentist about braces", due_date: "2026-08-15", due_time: nil
      )
    end

    it "parses a bare ordinal day-of-month still ahead this month (the 24th)" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist the 24th")).to include(
        title: "Call dentist", due_date: "2026-08-24", due_time: nil
      )
    end

    it "rolls a bare ordinal day-of-month to next month once it has passed (the 3rd)" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist the 3rd")).to include(
        title: "Call dentist", due_date: "2026-09-03", due_time: nil
      )
    end

    it "rolls to a month that actually has the ordinal day, skipping shorter months (the 31st)" do
      expect(QuickAdd.send(:roll_ordinal_day, Time.zone.local(2026, 5, 31, 10, 0, 0)).to_date).to eq(
        Date.new(2026, 7, 31)
      )
    end

    it "leaves a bare ordinal without 'the' in the title with no due date" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "Call dentist 24th")).to include(
        title: "Call dentist 24th", due_date: nil, due_time: nil
      )
    end
  end

  describe "recurrence extraction" do
    it "extracts every <weekday> phrases" do
      expect(described_class.parse("Call dentist every wednesday")).to include(
        title: "Call dentist", recurrence: "every wednesday"
      )
    end

    it "extracts every! with a count and unit, preserving the bang" do
      expect(described_class.parse("water plants every! 10 minutes")).to include(
        title: "water plants", recurrence: "every! 10 minutes"
      )
    end

    it "extracts every <unit> phrases" do
      expect(described_class.parse("stretch every day")).to include(
        title: "stretch", recurrence: "every day"
      )
    end

    it "extracts every N <unit> phrases" do
      expect(described_class.parse("walk every 3 days")).to include(
        title: "walk", recurrence: "every 3 days"
      )
    end

    it "extracts every <ordinal word> <weekday> phrases" do
      expect(described_class.parse("Trash day every other monday")).to include(
        title: "Trash day", recurrence: "every other monday"
      )
    end

    it "extracts every weekday" do
      expect(described_class.parse("sync every weekday")).to include(
        title: "sync", recurrence: "every weekday"
      )
    end

    it "normalizes the bare weekdays shorthand" do
      expect(described_class.parse("sync weekdays")).to include(
        title: "sync", recurrence: "every weekday"
      )
    end

    it "normalizes the bare workday shorthand" do
      expect(described_class.parse("sync workday")).to include(
        title: "sync", recurrence: "every weekday"
      )
    end

    it "extracts recurrence phrases case-insensitively" do
      expect(described_class.parse("Every Wednesday")).to include(
        title: "", recurrence: "every wednesday"
      )
    end

    it "leaves a malformed every phrase in the title (no extraction)" do
      expect(described_class.parse("water every potato")).to include(
        title: "water every potato", recurrence: nil
      )
    end

    it "does not extract a title that merely contains every" do
      expect(described_class.parse("clean every room")).to include(
        title: "clean every room", priority: nil, due_date: nil, due_time: nil, recurrence: nil
      )
    end

    it "consumes trailing punctuation attached to the recurrence phrase" do
      expect(described_class.parse("water plants every 3 days.")).to include(
        title: "water plants", recurrence: "every 3 days"
      )
      expect(described_class.parse("Take out trash workday!")).to include(
        title: "Take out trash", recurrence: "every weekday"
      )
      expect(described_class.parse("Every Wednesday.")).to include(
        title: "", recurrence: "every wednesday"
      )
    end
  end

  describe "in-X-unit due date extraction" do
    def parse_at(time, text)
      travel_to(time) { described_class.parse(text) }
    end

    it "extracts 'in <N> days' as an all-day due date" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "walk dog in 3 days")).to include(
        title: "walk dog", due_date: "2026-08-18", due_time: nil
      )
    end

    it "extracts 'in <N> hours' as a timed due date" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "check oven in 2 hours")).to include(
        title: "check oven", due_date: "2026-08-15", due_time: "12:00"
      )
    end

    it "extracts 'in <N> minutes' as a timed due date" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "water plants in 15 minutes")).to include(
        title: "water plants", due_date: "2026-08-15", due_time: "10:15"
      )
    end

    it "extracts 'in <N> weeks' as an all-day due date" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "renew pass in 1 week")).to include(
        title: "renew pass", due_date: "2026-08-22", due_time: nil
      )
    end

    it "extracts 'in <N> months' as an all-day due date" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "review lease in 6 months")).to include(
        title: "review lease", due_date: "2027-02-15", due_time: nil
      )
    end

    it "extracts 'in <N> years' as an all-day due date" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "renew passport in 1 year")).to include(
        title: "renew passport", due_date: "2027-08-15", due_time: nil
      )
    end

    it "resolves 'a'/'an' to a count of 1" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "renew pass in a week")).to include(
        title: "renew pass", due_date: "2026-08-22", due_time: nil
      )
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "check oven in an hour")).to include(
        title: "check oven", due_date: "2026-08-15", due_time: "11:00"
      )
    end

    it "strips the phrase cleanly when mid-title" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "call mom in 3 days about trip")).to include(
        title: "call mom about trip", due_date: "2026-08-18", due_time: nil
      )
    end

    it "strips the phrase cleanly when at the end, absorbing trailing punctuation" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "walk dog in 3 days.")).to include(
        title: "walk dog", due_date: "2026-08-18", due_time: nil
      )
    end

    it "does not match a title that merely contains a unit word without 'in <count>'" do
      expect(described_class.parse("review 3 days worth of logs")).to include(
        title: "review 3 days worth of logs", due_date: nil, due_time: nil
      )
    end

    it "does not interact with the recurrence grammar in the same title" do
      expect(described_class.parse("water plants every monday")).to include(
        recurrence: "every monday", due_date: nil, due_time: nil
      )
    end

    it "coexists with recurrence grammar in the same title" do
      expect(parse_at(Time.zone.local(2026, 8, 15, 10, 0, 0), "every monday in 3 days clean desk")).to include(
        title: "clean desk", recurrence: "every monday", due_date: "2026-08-18", due_time: nil
      )
    end
  end

  describe "anchored date grammar" do
    def parse_at(time, text)
      travel_to(time) { described_class.parse(text) }
    end

    it "resolves a one-shot nth weekday in a month" do
      expect(parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "ship it first monday in september")).to include(
        title: "ship it", due_date: "2026-09-07", due_time: nil, recurrence: nil, due_error: nil
      )
    end

    it "rolls a passed one-shot to next year" do
      expect(parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "first monday in august")).to include(
        due_date: "2027-08-02"
      )
    end

    it "resolves a one-shot business day with a time" do
      expect(parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "invoices first workday in september at 9am")).to include(
        title: "invoices", due_date: "2026-09-01", due_time: "09:00"
      )
    end

    it "reports due_error for an impossible one-shot day, no due_date" do
      result = parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "party 6th monday in feb")
      expect(result[:due_date]).to be_nil
      expect(result[:due_error]).to match(/6th monday in feb/i)
    end

    it "reports due_error when the nth day is absent that specific year" do
      expect(parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "5th monday in feb")[:due_error]).to match(/5th monday in feb/i)
    end

    it "extracts a yearly-anchored recurrence (bang)" do
      expect(parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "plan offsite every! first monday in jun")).to include(
        title: "plan offsite", recurrence: "every! first monday in jun", due_date: nil, due_error: nil
      )
    end

    it "extracts a yearly-anchored recurrence (no bang)" do
      expect(parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "board meeting every first monday in june")).to include(
        recurrence: "every first monday in june"
      )
    end

    it "a no-'every' anchored phrase is a one-off date, not a recurrence" do
      expect(parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "first workday in september")).to include(
        due_date: "2026-09-01", recurrence: nil
      )
    end

    it "bare workday shorthand still means every weekday" do
      expect(parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "take out trash workday")).to include(
        recurrence: "every weekday"
      )
    end

    it "does not strip the weekdays shorthand from the title when an explicit recurrence is present" do
      expect(described_class.parse("buy weekdays supplies every monday")).to include(
        title: "buy weekdays supplies", recurrence: "every monday"
      )
    end

    it "accepts a yearly-anchored recurrence without the optional 'in'" do
      expect(parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "board meeting every first monday june"))
        .to include(recurrence: "every first monday in june")
    end

    it "captures the optional time on a yearly-anchored recurrence" do
      expect(parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "review budget every third monday in jun at 3pm"))
        .to include(title: "review budget", recurrence: "every third monday in jun", due_time: "15:00", due_date: nil)
    end

    it "leaves due_time nil for a yearly-anchored recurrence without a time" do
      expect(parse_at(Time.zone.local(2026, 8, 26, 9, 0, 0), "every last friday in march"))
        .to include(recurrence: "every last friday in march", due_time: nil)
    end
  end
end
