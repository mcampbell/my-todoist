# Pure recurrence parsing + next-due computation. No DB, no state.
#
# Grammar (specs/design.md): "every"/"every!" (bang = rolling) + optional N +
# a unit: day(s)/week(s)/month(s)/year(s)/hour(s)/minute(s), a weekday name
# (monday..sunday), or weekday/workday (business day).
#
# Fixed (no bang) marches from the original due_at in whole intervals until
# the result reached now, preserving phase. Rolling (bang) schedules from now
# in one shot. `every month`/`every N months` lands on the 1st of the target
# month, discarding day-of-month (no short-month clamping drift).
class Recurrence
  class InvalidError < StandardError; end

  # Ruby Time#wday: 0 = Sunday .. 6 = Saturday.
  WEEKDAYS = { monday: 1, tuesday: 2, wednesday: 3, thursday: 4,
               friday: 5, saturday: 6, sunday: 0 }.freeze
  INTERVAL_UNITS = %i[day week year hour minute].freeze
  WEEKDAY_NAME_UNITS = WEEKDAYS.keys.freeze

  ORDINAL_WORDS = {
    "other" => 2, "first" => 1, "second" => 2, "third" => 3, "fourth" => 4,
    "fifth" => 5, "sixth" => 6, "seventh" => 7, "eighth" => 8, "ninth" => 9,
    "tenth" => 10, "eleventh" => 11, "twelfth" => 12, "thirteenth" => 13,
    "fourteenth" => 14, "fifteenth" => 15, "sixteenth" => 16, "seventeenth" => 17,
    "eighteenth" => 18, "nineteenth" => 19, "twentieth" => 20
  }.freeze

  UNIT_RE = /days?|weeks?|months?|years?|hours?|minutes?|mondays?|tuesdays?|wednesdays?|thursdays?|fridays?|saturdays?|sundays?|weekdays?|workdays?/
  COUNT_RE = /\d+(?:'?(?:st|nd|rd|th))?|#{ORDINAL_WORDS.keys.join('|')}/
  GRAMMAR = /\Aevery(?<bang>!)?\s+(?:(?<count>#{COUNT_RE})\s+)?(?<unit>#{UNIT_RE})\z/i
  # Yearly-anchored form: "every[!] {ordinal/last} {day/weekday} in <month>".
  # Shares its vocabulary with the one-shot PointInTime grammar.
  ANCHORED_GRAMMAR = /\Aevery(?<bang>!)?\s+(?<ord>#{CalendarTerms::ORDINAL_RE})\s+(?<day>#{CalendarTerms::DAY_RE})\s+(?:in\s+)?(?<month>#{CalendarTerms::MONTH_RE})\z/i
  # Yearly month + day-of-month form: "every[!] <month> <day>" (e.g. "every
  # sep 20") -- a fixed calendar date each year. Canonical (month-first) shape;
  # QuickAdd normalises "every 20 sep" to this before storing.
  ANCHORED_DOM_GRAMMAR = /\Aevery(?<bang>!)?\s+(?<month>#{CalendarTerms::MONTH_RE})\s+(?<day>\d{1,2})\z/i

  attr_reader :unit, :count

  def self.parse(string)
    return nil if string.blank?

    normalized = string.strip.downcase
    if (anchored = ANCHORED_GRAMMAR.match(normalized))
      return build_anchored(anchored)
    end

    if (dom = ANCHORED_DOM_GRAMMAR.match(normalized))
      return build_anchored_dom(dom)
    end

    match = GRAMMAR.match(normalized)
    raise InvalidError, "unrecognized recurrence: #{string.inspect}" unless match

    count = match[:count] ? resolve_count(match[:count]) : 1
    unit = normalize_unit(match[:unit])
    raise InvalidError, "invalid recurrence: #{string.inspect}" if count < 1

    new(unit: unit, count: count, rolling: match[:bang].present?)
  end

  # A yearly-anchored rule must be valid every year: reject an ordinal above
  # the month's guaranteed count (e.g. "every 5th monday in feb"), so
  # #next_from never faces a year whose month lacks the target. :last always
  # exists.
  def self.build_anchored(match)
    ordinal = CalendarTerms.ordinal(match[:ord])
    token = CalendarTerms.token(match[:day])
    month = CalendarTerms.month_number(match[:month])

    unless ordinal == :last || (ordinal >= 1 && ordinal <= MonthDay.guaranteed_min(month, token))
      raise InvalidError, "no #{match[:ord]} #{match[:day]} in #{match[:month]}"
    end

    new(unit: :anchored, rolling: match[:bang].present?, ordinal: ordinal, token: token, month: month)
  end
  private_class_method :build_anchored

  # A month + day-of-month rule must exist in some year: reject a day no year
  # of the month ever has (Feb 30, Sep 31, ...). Feb 29 is allowed; #next_from
  # walks past the non-leap years that lack it.
  def self.build_anchored_dom(match)
    month = CalendarTerms.month_number(match[:month])
    day = match[:day].to_i

    unless day >= 1 && day <= MonthDay.days_max(month)
      raise InvalidError, "no #{match[:month]} #{match[:day]}"
    end

    new(unit: :anchored, rolling: match[:bang].present?, month: month, day: day)
  end
  private_class_method :build_anchored_dom

  def self.resolve_count(token)
    token[0] =~ /\d/ ? token.to_i : ORDINAL_WORDS.fetch(token)
  end
  private_class_method :resolve_count

  def self.normalize_unit(word)
    unit = word.to_s.sub(/s\z/, "").to_sym
    unit == :workday ? :weekday : unit
  end
  private_class_method :normalize_unit

  def initialize(unit:, count: 1, rolling: false, ordinal: nil, token: nil, month: nil, day: nil)
    @unit = unit
    @count = count
    @rolling = rolling
    @ordinal = ordinal
    @token = token
    @month = month
    @day = day
  end

  def rolling?
    @rolling
  end

  # Gap in duration for interval units (day/week/year/hour/minute); nil for
  # weekday-name, business-day, and month units whose stepping is non-uniform.
  def interval
    return unless INTERVAL_UNITS.include?(unit)

    count.public_send("#{unit}s")
  end

  # Next due_at after completing a task scheduled at `due_at`, observed at
  # `now`.
  def next_from(due_at:, now: Time.current)
    raise ArgumentError, "due_at required" if due_at.nil?

    if unit == :anchored
      advance_anchored(due_at, now)
    elsif WEEKDAY_NAME_UNITS.include?(unit)
      advance_weekday(due_at, now)
    elsif unit == :weekday
      advance_business_day(due_at, now)
    elsif unit == :month
      advance_month(due_at, now)
    elsif rolling?
      now + interval
    else
      fixed_step(due_at, now)
    end
  end

  # The first occurrence of this rule on or after `on_or_after` (a Date).
  # Returns a Date. `count` and `rolling?` are ignored -- the first
  # occurrence is never stepped. Used to seed a new recurring task's
  # due_date from a "starting" anchor (and, with today as the anchor, for
  # the plain bootstrap). Sub-day units (hour/minute) resolve to the anchor
  # date; the caller adds the clock time.
  def first_occurrence(on_or_after:)
    date = on_or_after.to_date

    if unit == :anchored
      first_anchored_on_or_after(date)
    elsif WEEKDAY_NAME_UNITS.include?(unit)
      date + wday_delta(date.wday, WEEKDAYS.fetch(unit), inclusive: true)
    elsif unit == :weekday
      date += 1 while [ 0, 6 ].include?(date.wday)
      date
    elsif unit == :month
      first = date.beginning_of_month
      date.day == 1 ? first : first.next_month
    else # interval day/week/year/hour/minute -- the anchor becomes the phase
      date
    end
  end

  private

  # Calendar days from `from_wday` to `target_wday`. `inclusive: true` keeps
  # a same-day match at 0; `inclusive: false` bumps it to a full week (the
  # "strictly after" rule that #next_from's stepping needs).
  def wday_delta(from_wday, target_wday, inclusive:)
    delta = (target_wday - from_wday) % 7
    delta.zero? && !inclusive ? 7 : delta
  end

  # First `occurrence_in` date (no clock time) on or after `date`, walking
  # years past any the target is absent from (Feb 29 in a common year).
  def first_anchored_on_or_after(date)
    year = date.year
    loop do
      occ = @day ? day_of_month(year) : MonthDay.nth_of(year, @month, @ordinal, @token)
      return occ if occ && occ >= date

      year += 1
    end
  end

  # Yearly-anchored: the target is the ordinal/last <token>, or the fixed
  # day-of-month, of <month>, carrying the anchor's clock time. Fixed counts
  # from the original due_at; rolling counts from completion (now). Walk years
  # until the occurrence is strictly after the anchor and not in the past.
  # occurrence_in is nil for a year that lacks the target (only Feb 29 in a
  # non-leap year); skip it. Feb 29 recurs, so a leap year always follows.
  def advance_anchored(due_at, now)
    anchor = rolling? ? now : due_at
    year = anchor.year
    loop do
      result = occurrence_in(year, anchor)
      return result if result && result > anchor && result >= now

      year += 1
    end
  end

  def occurrence_in(year, anchor)
    date = @day ? day_of_month(year) : MonthDay.nth_of(year, @month, @ordinal, @token)
    return if date.nil?

    date.in_time_zone.change(hour: anchor.hour, min: anchor.min, sec: anchor.sec)
  end

  # The @day of @month in `year`, or nil when that year lacks it (Feb 29).
  def day_of_month(year)
    Date.new(year, @month, @day) if Date.valid_date?(year, @month, @day)
  end

  def advance_weekday(due_at, now)
    anchor = rolling? ? now : due_at
    result = next_occurrence_of_weekday(anchor, count)
    unless rolling?
      result = next_occurrence_of_weekday(result, count) while result < now
    end
    result
  end

  # Next calendar date `steps` occurrences of this recurrent weekday after
  # the anchor, preserving the anchor's clock time.
  def next_occurrence_of_weekday(anchor, steps)
    delta = wday_delta(anchor.wday, WEEKDAYS.fetch(unit), inclusive: false)
    anchor + delta.days + (steps - 1) * 7.days
  end

  # Business-day recurrence: advance one calendar day at a time, skipping
  # Saturday and Sunday, `count` business days per step.
  def advance_business_day(due_at, now)
    anchor = rolling? ? now : due_at
    result = next_business_day(anchor, count)
    result = next_business_day(result, count) while result < now unless rolling?
    result
  end

  def next_business_day(time, steps)
    candidate = time
    steps.times do
      candidate += 1.day
      candidate += 1.day while [ 0, 6 ].include?(candidate.wday)
    end
    candidate
  end

  # Month/N-months lands on the 1st of the target month. Fixed: take the 1st
  # of the anchor's month, then advance N calendar months until now is
  # reached. Rolling: the 1st of the month N months from now.
  def advance_month(due_at, now)
    first_of_anchor_month = due_at.change(day: 1)
    if rolling?
      count.months.since(now).beginning_of_month
    else
      result = count.months.since(first_of_anchor_month)
      result = count.months.since(result) while result < now
      result
    end
  end

  # Fixed interval stepping: `next = original due_at + interval`, then keep
  # adding whole intervals until the result reached now. Never jumps straight
  # to now — preserves phase.
  def fixed_step(due_at, now)
    result = due_at + interval
    result += interval while result < now
    result
  end
end
