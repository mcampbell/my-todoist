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

    context "off macOS" do
      before { allow(described_class).to receive(:macos?).and_return(false) }

      it "does not shell out" do
        expect(Open3).not_to receive(:capture3)
        described_class.notify(title: "Buy milk", message: "It's due")
      end
    end
  end
end
