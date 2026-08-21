require "open3"

# Native OS notification, macOS only for now (single-user local app —
# see CLAUDE.md). Pure OS detection + shell-out; no state, no DB.
class OsNotifier
  def self.macos?
    RbConfig::CONFIG["host_os"].to_s.match?(/darwin/i)
  end

  # Open3.capture3 execs osascript as a real subprocess (array args, no
  # shell), so quote-escaping the AppleScript string is only about valid
  # AppleScript syntax, not injection.
  def self.notify(title:, message:)
    return unless macos?

    script = %(display notification "#{escape(message)}" with title "#{escape(title)}")
    Open3.capture3("osascript", "-e", script)
  end

  def self.escape(text)
    text.to_s.gsub("\\") { "\\\\" }.gsub('"') { '\"' }
  end
  private_class_method :escape
end
