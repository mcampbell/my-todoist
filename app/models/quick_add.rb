# Parses quick-add free text into task attributes.
# Permissive by design: unrecognized tokens stay in the title.
class QuickAdd
  PRIORITY_TOKENS = { 1 => 3, 2 => 2, 3 => 1, 4 => 0 }.freeze
  PRIORITY_RE = /\bp([1-4])\b/

  # Returns { title:, priority: }. priority is nil when no token is present.
  def self.parse(text)
    title = text.to_s.dup
    priority = nil
    if (match = title.match(PRIORITY_RE))
      priority = PRIORITY_TOKENS.fetch(match[1].to_i)
      title[match.begin(0)...match.end(0)] = ""
    end
    { title: title.strip.squeeze(" "), priority: priority }
  end
end
