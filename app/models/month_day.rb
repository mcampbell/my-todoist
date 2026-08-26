# Pure calendar math shared by the point-in-time (one-shot) and anchored
# (recurring) grammars. No DB, no state.
#
# A "token" is either a named weekday (:monday .. :sunday) or :business
# (a Mon-Fri business day). `nth_of` locates the nth (or :last) such day in a
# month; `guaranteed_min` reports how many are certain in a month across every
# possible year, so the recurring grammar can reject a rule that some years
# would leave without a target (e.g. "every 5th monday in feb").
module MonthDay
  module_function

  # Ruby Date#wday: 0 = Sunday .. 6 = Saturday. Reused from Recurrence so the
  # two grammars agree on weekday numbering.
  WEEKDAYS = Recurrence::WEEKDAYS

  # Calendar day count per month; February varies by year so it is handled
  # separately in `guaranteed_min` and not looked up here.
  MONTH_LENGTHS = [ nil, 31, nil, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ].freeze

  # The nth matching day of the given month, or :last for the final one.
  # Returns a Date, or nil when that occurrence does not exist (e.g. a 6th
  # Monday, or the 21st business day of a 20-business-day month).
  def nth_of(year, month, ordinal, token)
    return nil if ordinal != :last && ordinal < 1

    days = matching_days(year, month, token)
    return days.last if ordinal == :last

    days[ordinal - 1]
  end

  # Smallest count of `token` days guaranteed in `month` across all years:
  # the minimum over {common, leap February lengths} x {every possible
  # first-weekday}. An ordinal at or below this is safe every year; above it
  # is not. :last is always safe and needs no check.
  def guaranteed_min(month, token)
    lengths(month).product((0..6).to_a).map { |len, start| count_in(len, start, token) }.min
  end

  def matching_days(year, month, token)
    last_day = Date.new(year, month, -1).day
    (1..last_day).map { |d| Date.new(year, month, d) }.select { |date| matches?(date, token) }
  end
  private_class_method :matching_days

  def matches?(date, token)
    if token == :business
      ![ 0, 6 ].include?(date.wday)
    else
      date.wday == WEEKDAYS.fetch(token)
    end
  end
  private_class_method :matches?

  def lengths(month)
    month == 2 ? [ 28, 29 ] : [ MONTH_LENGTHS.fetch(month) ]
  end
  private_class_method :lengths

  # How many `token` days fall in a hypothetical month of `len` days whose
  # first day is weekday `start_wday`. Pure arithmetic, no real date needed.
  def count_in(len, start_wday, token)
    (0...len).count do |offset|
      wday = (start_wday + offset) % 7
      token == :business ? ![ 0, 6 ].include?(wday) : wday == WEEKDAYS.fetch(token)
    end
  end
  private_class_method :count_in
end
