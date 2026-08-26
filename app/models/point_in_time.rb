# One-shot anchored-date grammar:
#   "{first/last/nth} {weekday/workday/<day>} [in] <month> [[at] <time>]"
#
# Resolves to a single calendar date (non-recurring). The missing year is
# filled to the nearest upcoming <month>; if that occurrence has already
# passed, it rolls one year and re-checks. When the requested ordinal does
# not exist in the resolved month (e.g. "6th monday in feb"), it raises
# InvalidError with a message naming the phrase -- the caller surfaces that on
# errors[:due_at]. Pure computation: no DB, no state.
class PointInTime
  # Carries the matched span so the caller can strip the offending phrase
  # from the title without re-running the regex.
  class InvalidError < StandardError
    attr_reader :range

    def initialize(message, range)
      super(message)
      @range = range
    end
  end

  SHAPE = /(?<ord>#{CalendarTerms::ORDINAL_RE})\s+(?<day>#{CalendarTerms::DAY_RE})\s+(?:in\s+)?(?<month>#{CalendarTerms::MONTH_RE})(?:\s+(?:at\s+)?(?<time>#{CalendarTerms::TIME_RE}))?/i

  Result = Struct.new(:date, :time, :range) do
    def due_date
      date.iso8601
    end
  end

  # Returns a Result, or nil when the text carries no anchored-date shape.
  # Raises InvalidError when the shape is present but the ordinal cannot exist
  # in the resolved month.
  def self.parse(text, now: Time.current)
    match = SHAPE.match(text.to_s)
    return nil unless match

    ordinal = CalendarTerms.ordinal(match[:ord])
    token = CalendarTerms.token(match[:day])
    month = CalendarTerms.month_number(match[:month])
    time = CalendarTerms.time(match[:time])

    range = match.begin(0)...match.end(0)
    date = resolve_date(ordinal, token, month, time, now)
    raise InvalidError.new("no #{match[:ord]} #{match[:day]} in #{match[:month]}".downcase, range) if date.nil?

    Result.new(date, time, range)
  end

  # Nearest upcoming <month>: this year when the month is still ahead, else
  # next year. If the resolved day has already passed, roll one year and
  # re-check. Returns nil (not a roll) when the ordinal is absent in the
  # resolved month -- the one-shot grammar errors rather than scanning years.
  def self.resolve_date(ordinal, token, month, time, now)
    today = now.to_date
    year = month >= today.month ? today.year : today.year + 1
    date = MonthDay.nth_of(year, month, ordinal, token)
    return nil if date.nil?

    date = MonthDay.nth_of(year + 1, month, ordinal, token) if past?(date, time, now)
    date
  end
  private_class_method :resolve_date

  def self.past?(date, time, now)
    if time
      hour, min = time.split(":").map(&:to_i)
      date.in_time_zone.change(hour: hour, min: min) <= now
    else
      date < now.to_date
    end
  end
  private_class_method :past?
end
