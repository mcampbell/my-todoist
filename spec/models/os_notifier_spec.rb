require "rails_helper"

RSpec.describe OsNotifier do
  describe ".macos?" do
    it "is true when host_os reports darwin" do
      stub_const("RbConfig::CONFIG", RbConfig::CONFIG.merge("host_os" => "darwin23"))
      expect(described_class.macos?).to be true
    end

    it "is false on other platforms" do
      stub_const("RbConfig::CONFIG", RbConfig::CONFIG.merge("host_os" => "linux-gnu"))
      expect(described_class.macos?).to be false
    end
  end

  describe ".wsl?" do
    it "is true when /proc/version mentions microsoft" do
      allow(File).to receive(:read).with("/proc/version")
        .and_return("Linux version 5.15.0 (Microsoft@Microsoft.com)")
      expect(described_class.wsl?).to be true
    end

    it "is false on plain Linux" do
      allow(File).to receive(:read).with("/proc/version")
        .and_return("Linux version 6.6.0 (gcc)")
      expect(described_class.wsl?).to be false
    end

    it "is false when /proc/version doesn't exist (e.g. macOS)" do
      allow(File).to receive(:read).with("/proc/version").and_raise(Errno::ENOENT)
      expect(described_class.wsl?).to be false
    end
  end

  describe ".notify" do
    context "on macOS" do
      before { allow(described_class).to receive(:macos?).and_return(true) }

      it "shells out to osascript with the title and message as separate args" do
        expect(Open3).to receive(:capture3).with(
          "osascript", "-e",
          "display notification \"It's due\" with title \"Buy milk\""
        )

        described_class.notify(title: "Buy milk", message: "It's due")
      end

      it "escapes double quotes in title and message" do
        expect(Open3).to receive(:capture3).with(
          "osascript", "-e",
          "display notification \"say \\\"hi\\\"\" with title \"a \\\"b\\\" c\""
        )

        described_class.notify(title: 'a "b" c', message: 'say "hi"')
      end

      it "escapes backslashes before quotes so quote-escaping isn't itself re-escaped" do
        expect(Open3).to receive(:capture3).with(
          "osascript", "-e",
          "display notification \"C:\\\\path\" with title \"a\\\\b\""
        )

        described_class.notify(title: 'a\b', message: 'C:\path')
      end
    end

    context "on WSL2" do
      before do
        allow(described_class).to receive(:macos?).and_return(false)
        allow(described_class).to receive(:wsl?).and_return(true)
      end

      it "spawns powershell.exe detached with a NotifyIcon balloon tip, without blocking on it" do
        expect(Process).to receive(:spawn) do |*args, **opts|
          expect(args[0..2]).to eq([ "powershell.exe", "-NoProfile", "-Command" ])
          expect(args[3]).to include("$notify.ShowBalloonTip(5000, 'Buy milk', 'It''s due',")
          expect(opts).to eq(out: File::NULL, err: File::NULL)
          4321
        end
        expect(Process).to receive(:detach).with(4321)

        described_class.notify(title: "Buy milk", message: "It's due")
      end

      it "escapes single quotes by doubling them (PowerShell string escaping)" do
        allow(Process).to receive(:spawn) do |*args|
          expect(args[3]).to include("'It''s O''Brien''s task'''")
          4321
        end
        allow(Process).to receive(:detach)

        described_class.notify(title: "Buy milk", message: "It's O'Brien's task'")
      end
    end

    context "off macOS and off WSL" do
      before do
        allow(described_class).to receive(:macos?).and_return(false)
        allow(described_class).to receive(:wsl?).and_return(false)
      end

      it "does not shell out" do
        expect(Open3).not_to receive(:capture3)
        described_class.notify(title: "Buy milk", message: "It's due")
      end
    end
  end
end
