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
    recurrence = extract_recurrence!(title)
    due_date, due_time = extract_due_offset!(title)

    if !due_date && (span = date_span(title))
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
      recurrence: recurrence
    }
  end

  # Extracts and normalizes a recurrence phrase, removing it from the title.
  # Returns the canonical recurrence string, or nil when none is present.
  def self.extract_recurrence!(title)
    if (match = title.match(RECURRENCE_RE))
      finish = recurrence_span_end(title, match.end(0))
      title[match.begin(0)...finish] = ""
      bang = match[:bang].empty? ? "" : "!"
      count = match[:count] ? "#{match[:count]} " : ""
      return "every#{bang} #{count}#{match[:unit].downcase}"
    end

    if (match = title.match(WEEKDAYS_SHORTHAND_RE))
      finish = recurrence_span_end(title, match.end(0))
      title[match.begin(0)...finish] = ""
      return "every weekday"
    end

    nil
  end
  private_class_method :extract_recurrence!

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
      next unless date_word?(bare) || time_anchor?(bare)

      j = i
      j += 1 while words[j + 1] && anchor_word?(words[j + 1][0])
      k = i
      k -= 1 while k > 0 && NUMBER_RE.match?(classify(words[k - 1][0]))
      span_words = words[k..j]

      parsed = nil
      attempt = span_words
      loop do
        parsed = Chronic.parse(attempt.map { |w| chronic_word(classify(w[0])) }.join(" "))
        break if parsed || attempt.length == 1 || attempt.first.equal?(words[i])
        attempt = attempt[1..]
      end
      next unless parsed

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
    CHRONIC_SYNONYMS[word.downcase] || word
  end
  private_class_method :chronic_word

  def self.date_word?(word)
    DATE_WORD_RE.match?(word)
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
end
