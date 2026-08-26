# Parses quick-add free text into task attributes.
# Permissive by design: unrecognized tokens stay in the title.
class QuickAdd
  PRIORITY_TOKENS = { 1 => 3, 2 => 2, 3 => 1, 4 => 0 }.freeze
  PRIORITY_RE = /\bp([1-4])\b/
  PROJECT_RE = /(?<!\w)#([^\s#]+)/

  # Recurrence grammar (specs/design.md): "every"/"every!" plus a day, unit,
  # weekday, or N-unit count; or the bare shorthand weekdays/workday. Runs
  # before chronic, which would otherwise parse "every weekday" as a one-off.
  RECURRENCE_RE = /\bevery(?<bang>!?)\s+(?:(?<count>#{Recurrence::COUNT_RE})\s+)?(?<unit>days?|weeks?|months?|years?|hours?|minutes?|monday|tuesday|wednesday|thursday|friday|saturday|sunday|weekday|workday)\b/i
  # Yearly-anchored recurrence, e.g. "every! first monday in jun". Must be
  # tried before RECURRENCE_RE, which would otherwise read "every first monday"
  # as a weekly Monday and strand "in jun" in the title. Shares its ordinal/
  # day/month vocabulary with PointInTime via CalendarTerms.
  ANCHORED_RECURRENCE_RE = /\bevery(?<bang>!?)\s+(?<ord>#{CalendarTerms::ORDINAL_RE})\s+(?<day>#{CalendarTerms::DAY_RE})\s+(?:in\s+)?(?<month>#{CalendarTerms::MONTH_RE})(?:\s+(?:at\s+)?(?<time>#{CalendarTerms::TIME_RE}))?\b/i
  # Bare "weekdays"/"workday" (no "every" prefix) is recurrence shorthand for
  # "every weekday" -- UNLESS it is "next"/"last" + weekday/workday, which is
  # a one-off date (like "next monday" / "last monday"), not recurrence.
  WEEKDAYS_SHORTHAND_RE = /(?<!\bnext\s)(?<!\blast\s)\b(?:weekdays|workday)\b/i
  # "workday" isn't Chronic vocabulary (Chronic understands "weekday"); this
  # maps the one word we accept as input to the word we hand Chronic.
  CHRONIC_SYNONYMS = { "workday" => "weekday" }.freeze

  # "in X unit" date-pinning grammar (specs/in-x-unit-design.md): relative
  # offset from now, e.g. "in 3 days", "in 15 minutes", "in a week".
  IN_UNIT_RE = /\bin\s+(?:(?<count>\d+)|an?)\s+(?<unit>days?|hours?|minutes?|weeks?|months?|years?)\b/i

  WORD_RE = /[^\s]+/
  NUMBER_RE = /\A\d+(?:st|nd|rd|th)?\z/i
  # Words chronic recognizes as date material (used to find candidate spans).
  DATE_WORD_RE = /\A(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun|tomorrow|today|yesterday|next|last|weekday|workday|january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec|weeks?|months?|years?)\z/i
  # Compact dash/slash date token, e.g. "15-aug-2026", "15-aug", "15/aug/2026".
  COMPACT_DATE_RE = /\A\d{1,2}[-\/](?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)(?:[-\/]\d{2,4})?\z/i
  # Bare ordinal day-of-month, e.g. "24th" in "the 24th".
  ORDINAL_DAY_RE = /\A\d{1,2}(?:st|nd|rd|th)\z/i
  # Explicit time forms (digit and word) plus their standalone am/pm markers.
  TIME_ANCHOR_RE = /\A(?:\d{1,2}(?::\d{2})?\s*(?:am|pm)|\d{1,2}:\d{2}|noon|midnight|o'clock|am|pm)\z/i
  TRAILING_PUNCTUATION_RE = /[.,;!?]+\z/

  # Returns { title:, priority:, due_date:, due_time:, project_name:,
  # recurrence: }.
  # due_date is "YYYY-MM-DD", due_time is "HH:MM"; due_time, project_name,
  # and recurrence are nil when absent. due_time is set only for phrases with
  # an explicit time token — chronic's 12:00 default for bare dates never
  # leaks (the Task model derives all_day from due_time). project_name is the
  # trimmed #token text; matching is case-insensitive at the DB (NOCASE).
  # Recurrence phrases extract a `recurrence:` value (stored verbatim) and
  # leave the title; the bare shorthand weekdays/workday normalizes to
  # "every weekday".
  def self.parse(text)
    raw = text.to_s

    title = raw.dup
    priority = extract_priority!(title)
    recurrence, recurrence_time = extract_recurrence!(title)
    # Point-in-time runs after the "every"-prefixed recurrences (so those win)
    # but before the bare weekdays/workday shorthand (so "first workday in
    # september" is a one-off date, not an "every weekday" recurrence).
    due_date, due_time, due_error = extract_point_in_time!(title) if recurrence.nil?
    if recurrence.nil? && due_date.nil? && due_error.nil?
      recurrence = extract_weekday_shorthand!(title)
    end

    if !due_date && !due_error
      offset_date, offset_time = extract_due_offset!(title)
      due_date, due_time = offset_date, offset_time
    end

    if !due_date && !due_error && (span = date_span(title))
      parsed = span[:parsed]
      if span[:time_anchor]
        due_time = parsed.strftime("%H:%M")
        due_date = span[:date_anchor] ? parsed : roll_bare_time(parsed)
        due_date = due_date.to_date.iso8601
      else
        due_date = parsed.to_date.iso8601
      end
      title[span[:start]...span[:end]] = ""
    end

    due_time ||= recurrence_time

    project_name = nil
    if (match = title.match(PROJECT_RE))
      name = classify(match[1])
      if name.present?
        project_name = name
        title[match.begin(1) - 1...match.end(1)] = ""
      end
    end

    {
      title: title.strip.squeeze(" "),
      priority: priority,
      due_date: due_date,
      due_time: due_time,
      project_name: project_name,
      recurrence: recurrence,
      due_error: due_error
    }
  end

  # Extracts and normalizes a recurrence phrase, removing it from the title.
  # Returns the canonical recurrence string, or nil when none is present.
  # Returns [recurrence_string, due_time]. due_time is the optional "at <time>"
  # of an anchored recurrence ("every third monday in jun at 3pm"), which the
  # recurrence pattern itself does not carry -- it becomes the task's due_time
  # and the advance preserves that clock time. nil recurrence -> [nil, nil].
  def self.extract_recurrence!(title)
    if (match = title.match(ANCHORED_RECURRENCE_RE))
      finish = recurrence_span_end(title, match.end(0))
      title[match.begin(0)...finish] = ""
      bang = match[:bang].empty? ? "" : "!"
      recurrence = "every#{bang} #{match[:ord]} #{match[:day]} in #{match[:month]}".downcase
      return [ recurrence, CalendarTerms.time(match[:time]) ]
    end

    if (match = title.match(RECURRENCE_RE))
      finish = recurrence_span_end(title, match.end(0))
      title[match.begin(0)...finish] = ""
      bang = match[:bang].empty? ? "" : "!"
      count = match[:count] ? "#{match[:count]} " : ""
      return [ "every#{bang} #{count}#{match[:unit].downcase}", nil ]
    end

    [ nil, nil ]
  end
  private_class_method :extract_recurrence!

  # Bare "weekdays"/"workday" shorthand for "every weekday". Runs after
  # point-in-time so it never swallows the "workday" inside e.g. "first
  # workday in september".
  def self.extract_weekday_shorthand!(title)
    if (match = title.match(WEEKDAYS_SHORTHAND_RE))
      finish = recurrence_span_end(title, match.end(0))
      title[match.begin(0)...finish] = ""
      return "every weekday"
    end

    nil
  end
  private_class_method :extract_weekday_shorthand!

  # One-shot anchored date ("first monday in march [at 3pm]"). Delegates the
  # grammar to PointInTime; strips the matched span. Returns
  # [due_date, due_time, due_error]: due_error carries the "no 6th monday in
  # feb" message when the shape matched but the day does not exist, which the
  # controller surfaces on errors[:due_at].
  def self.extract_point_in_time!(title)
    result = PointInTime.parse(title)
    return [ nil, nil, nil ] if result.nil?

    strip_span!(title, result.range.begin, result.range.end)
    [ result.due_date, result.time, nil ]
  rescue PointInTime::InvalidError => e
    strip_span!(title, e.range.begin, e.range.end)
    [ nil, nil, e.message ]
  end
  private_class_method :extract_point_in_time!

  def self.strip_span!(title, from, to)
    title[from...recurrence_span_end(title, to)] = ""
  end
  private_class_method :strip_span!

  # The phrase sits mid-title or at its end; absorb attached sentence
  # punctuation (".", "!", "?") so it does not leak into the saved title.
  def self.recurrence_span_end(title, finish)
    finish += 1 while title[finish]&.match?("\\A[.,!?]\\z")
    finish
  end
  private_class_method :recurrence_span_end

  # Extracts an "in <count> <unit>" relative offset, removing it from the
  # title. Returns [due_date, due_time] ("YYYY-MM-DD", "HH:MM" or nil), or
  # [nil, nil] when no match.
  def self.extract_due_offset!(title)
    if (match = title.match(IN_UNIT_RE))
      finish = recurrence_span_end(title, match.end(0))
      title[match.begin(0)...finish] = ""

      count = match[:count]&.to_i || 1
      offset = count.public_send(match[:unit].downcase)
      target = Time.current + offset
      due_time = offset < 1.day ? target.strftime("%H:%M") : nil
      return [ target.to_date.iso8601, due_time ]
    end

    [ nil, nil ]
  end
  private_class_method :extract_due_offset!

  def self.extract_priority!(title)
    if (match = title.match(PRIORITY_RE))
      title[match.begin(0)...match.end(0)] = ""
      PRIORITY_TOKENS.fetch(match[1].to_i)
    end
  end
  private_class_method :extract_priority!

  # Finds the first date/time phrase: a run of date-ish words (date words,
  # time anchors, bare numbers) that chronic parses as a whole. Leading bare
  # numbers are absorbed ("3 pm", "20 aug"); if the full run does not parse,
  # leading words are dropped one at a time (never past the anchor word).
  def self.date_span(text)
    words = text.to_enum(:scan, WORD_RE).map { Regexp.last_match }
    words.each_with_index do |word, i|
      bare = classify(word[0])
      # Known limitation: this also matches non-date ordinals, e.g. "the 2nd
      # item" -- accepted trade-off (specs/specific-date-grill.md Q3).
      ordinal_day = ORDINAL_DAY_RE.match?(bare) && i > 0 && classify(words[i - 1][0]).casecmp?("the")
      next unless date_word?(bare) || time_anchor?(bare) || ordinal_day

      j = i
      j += 1 while words[j + 1] && anchor_word?(words[j + 1][0])
      k = i
      k -= 1 while k > 0 && NUMBER_RE.match?(classify(words[k - 1][0]))
      k -= 1 if ordinal_day
      span_words = words[k..j]

      parsed = nil
      attempt = span_words
      loop do
        parsed = Chronic.parse(attempt.map { |w| chronic_word(classify(w[0])) }.join(" "))
        break if parsed || attempt.length == 1 || attempt.first.equal?(words[i])
        attempt = attempt[1..]
      end
      next unless parsed

      parsed = roll_ordinal_day(parsed) if ordinal_day && parsed.to_date < Time.zone.now.to_date

      span_texts = attempt.map { |w| classify(w[0]) }
      return {
        parsed: parsed,
        start: attempt.first.begin(0),
        end: attempt.last.end(0),
        time_anchor: span_texts.any? { |w| time_anchor?(w) },
        date_anchor: span_texts.any? { |w| date_word?(w) }
      }
    end
    nil
  end
  private_class_method :date_span

  def self.anchor_word?(word)
    bare = classify(word)
    date_word?(bare) || time_anchor?(bare) || NUMBER_RE.match?(bare)
  end
  private_class_method :anchor_word?

  def self.classify(word)
    word.sub(TRAILING_PUNCTUATION_RE, "")
  end
  private_class_method :classify

  # Normalizes a classified word to whatever Chronic itself understands.
  def self.chronic_word(word)
    return word.tr("-/", " ") if COMPACT_DATE_RE.match?(word)
    CHRONIC_SYNONYMS[word.downcase] || word
  end
  private_class_method :chronic_word

  def self.date_word?(word)
    DATE_WORD_RE.match?(word) || COMPACT_DATE_RE.match?(word)
  end
  private_class_method :date_word?

  def self.time_anchor?(word)
    TIME_ANCHOR_RE.match?(word)
  end
  private_class_method :time_anchor?

  # A bare time phrase (no date word) implies a date: today when the time is
  # still strictly ahead, tomorrow when it is now or has passed.
  def self.roll_bare_time(time)
    time <= Time.current ? time + 1.day : time
  end
  private_class_method :roll_bare_time

  # A bare ordinal day-of-month ("the 3rd") that has already passed this
  # month means the next month that actually has that day-of-month --
  # plain `+ 1.month` would clamp e.g. the 31st into a 30-day month.
  def self.roll_ordinal_day(time)
    day = time.day
    month = Date.new(time.year, time.month, 1)
    loop do
      month = month.next_month
      break if Date.new(month.year, month.month, -1).day >= day
    end
    time.change(year: month.year, month: month.month, day: day)
  end
  private_class_method :roll_ordinal_day
end
