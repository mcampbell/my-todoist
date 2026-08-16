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

  attr_reader :unit, :count

  def self.parse(string)
    return nil if string.blank?

    match = GRAMMAR.match(string.strip.downcase)
    raise InvalidError, "unrecognized recurrence: #{string.inspect}" unless match

    count = match[:count] ? resolve_count(match[:count]) : 1
    unit = normalize_unit(match[:unit])
    raise InvalidError, "invalid recurrence: #{string.inspect}" if count < 1

    new(unit: unit, count: count, rolling: match[:bang].present?)
  end

  def self.resolve_count(token)
    token[0] =~ /\d/ ? token.to_i : ORDINAL_WORDS.fetch(token)
  end
  private_class_method :resolve_count

  def self.normalize_unit(word)
    unit = word.to_s.sub(/s\z/, "").to_sym
    unit == :workday ? :weekday : unit
  end
  private_class_method :normalize_unit

  def initialize(unit:, count: 1, rolling: false)
    @unit = unit
    @count = count
    @rolling = rolling
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

    if WEEKDAY_NAME_UNITS.include?(unit)
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

  private

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
    target = WEEKDAYS.fetch(unit)
    delta = (target - anchor.wday) % 7
    delta = 7 if delta.zero?
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
