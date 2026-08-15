require "rails_helper"

RSpec.describe QuickAdd, type: :model do
  describe ".parse" do
    it "maps p1 to priority 3" do
      expect(described_class.parse("buy milk p1")).to eq(title: "buy milk", priority: 3)
    end

    it "maps p2 to priority 2" do
      expect(described_class.parse("buy milk p2")).to eq(title: "buy milk", priority: 2)
    end

    it "maps p3 to priority 1" do
      expect(described_class.parse("buy milk p3")).to eq(title: "buy milk", priority: 1)
    end

    it "maps p4 to priority 0" do
      expect(described_class.parse("buy milk p4")).to eq(title: "buy milk", priority: 0)
    end

    it "strips the token wherever it appears in the text" do
      expect(described_class.parse("p2 buy milk")).to eq(title: "buy milk", priority: 2)
      expect(described_class.parse("buy p2 milk")).to eq(title: "buy milk", priority: 2)
    end

    it "leaves priority unset when no token is present" do
      expect(described_class.parse("buy milk")).to eq(title: "buy milk", priority: nil)
    end

    it "leaves malformed pN tokens as literal title text" do
      expect(described_class.parse("p5 buy p0 milk")).to eq(title: "p5 buy p0 milk", priority: nil)
    end

    it "strips only the first valid pN token" do
      expect(described_class.parse("p2 p4 milk")).to eq(title: "p4 milk", priority: 2)
    end

    it "does not treat pN inside a larger word as a token" do
      expect(described_class.parse("check apple1")).to eq(title: "check apple1", priority: nil)
    end

    it "collapses leftover whitespace around the stripped token" do
      expect(described_class.parse("buy  p2   milk")).to eq(title: "buy milk", priority: 2)
    end
  end
end
