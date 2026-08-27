# Shared vocabulary for the anchored-date grammars (one-shot PointInTime and
# recurring Recurrence): ordinal words, weekday/business-day tokens, and month
# names, plus the regex fragments that recognise them. Keeping the tables in
# one place stops the two grammars (and QuickAdd's recurrence regex) from
# drifting apart. Date arithmetic lives in MonthDay; this module is only
# string -> value mapping.
module CalendarTerms
  module_function

  ORDINAL_WORDS = { "first" => 1, "second" => 2, "third" => 3, "fourth" => 4, "fifth" => 5 }.freeze
  DAY_ABBREV = { "mon" => :monday, "tue" => :tuesday, "wed" => :wednesday, "thu" => :thursday,
                 "fri" => :friday, "sat" => :saturday, "sun" => :sunday }.freeze
  MONTH_NAMES = %w[january february march april may june july august september october november december].freeze

  # Longer alternatives first so e.g. "sept" wins over "sep" and "monday" over
  # "mon" -- otherwise the shorter match leaves a stray letter in the title.
  # Each fragment carries its own /i so it stays case-insensitive wherever it
  # is interpolated: a nested Regexp embeds as (?i-mx:...) and ignores the
  # host pattern's flags, so without this a caller's /i would not reach here.
  ORDINAL_RE = /first|second|third|fourth|fifth|last|\d{1,2}(?:st|nd|rd|th)/i
  DAY_RE = /mondays?|tuesdays?|wednesdays?|thursdays?|fridays?|saturdays?|sundays?|mon|tue|wed|thu|fri|sat|sun|weekday|workday/i
  MONTH_RE = /january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sept|sep|oct|nov|dec/i
  TIME_RE = /\d{1,2}:\d{2}\s*(?:am|pm)?|\d{1,2}\s*(?:am|pm)|noon|midnight/i

  # Integer >= 1, or :last.
  def ordinal(text)
    key = text.downcase
    return :last if key == "last"
    return ORDINAL_WORDS[key] if ORDINAL_WORDS.key?(key)

    key.to_i
  end

  # A weekday symbol (:monday .. :sunday) or :business (Mon-Fri).
  def token(text)
    word = text.downcase.sub(/s\z/, "")
    return :business if %w[weekday workday].include?(word)
    return DAY_ABBREV[word] if DAY_ABBREV.key?(word)

    word.to_sym
  end

  # 1..12.
  def month_number(text)
    prefix = text.downcase.sub(/\Asept\z/, "sep")[0, 3]
    MONTH_NAMES.index { |name| name.start_with?(prefix) } + 1
  end

  # "HH:MM", or nil for blank input.
  def time(text)
    return nil if text.blank?
    return "12:00" if text.casecmp?("noon")
    return "00:00" if text.casecmp?("midnight")

    Time.zone.parse(text).strftime("%H:%M")
  end
end
