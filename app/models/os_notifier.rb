require "open3"

# Native OS notification. Single-user local app (see CLAUDE.md), so this
# always targets the machine the server runs on. Pure OS detection +
# shell-out; no state, no DB.
class OsNotifier
  def self.macos?
    RbConfig::CONFIG["host_os"].to_s.match?(/darwin/i)
  end

  # WSL2's Ruby reports host_os "linux" like any other Linux — the only
  # signal is the kernel string in /proc/version.
  def self.wsl?
    File.read("/proc/version").match?(/microsoft/i)
  rescue Errno::ENOENT
    false
  end

  # Open3.capture3 execs as a real subprocess (array args, no shell), so
  # quote-escaping the embedded script is only about valid AppleScript/
  # PowerShell syntax, not injection.
  def self.notify(title:, message:)
    if macos?
      notify_macos(title, message)
    elsif wsl?
      notify_wsl(title, message)
    end
  end

  def self.notify_macos(title, message)
    script = %(display notification "#{escape_applescript(message)}" with title "#{escape_applescript(title)}")
    Open3.capture3("osascript", "-e", script)
  end
  private_class_method :notify_macos

  # Windows has no built-in modern-toast CLI reachable without installing a
  # PowerShell module (BurntToast); NotifyIcon's balloon tip ships with
  # .NET and needs nothing extra installed, so it's the toast this can pop
  # without asking the user to set anything up on the Windows side.
  #
  # The script keeps the process alive (Start-Sleep) so the balloon has
  # time to render before $notify.Dispose() removes the tray icon — but
  # that means the subprocess itself takes 6+ seconds to exit. Spawn it
  # detached (Process.spawn + detach) instead of Open3.capture3, which
  # would otherwise block the calling request thread for that whole time.
  def self.notify_wsl(title, message)
    script = <<~PS
      Add-Type -AssemblyName System.Windows.Forms
      $notify = New-Object System.Windows.Forms.NotifyIcon
      $notify.Icon = [System.Drawing.SystemIcons]::Information
      $notify.Visible = $true
      $notify.ShowBalloonTip(5000, '#{escape_powershell(title)}', '#{escape_powershell(message)}', [System.Windows.Forms.ToolTipIcon]::Info)
      Start-Sleep -Seconds 6
      $notify.Dispose()
    PS
    pid = Process.spawn("powershell.exe", "-NoProfile", "-Command", script, out: File::NULL, err: File::NULL)
    Process.detach(pid)
  end
  private_class_method :notify_wsl

  def self.escape_applescript(text)
    text.to_s.gsub("\\") { "\\\\" }.gsub('"') { '\"' }
  end
  private_class_method :escape_applescript

  def self.escape_powershell(text)
    text.to_s.gsub("'", "''")
  end
  private_class_method :escape_powershell
end
