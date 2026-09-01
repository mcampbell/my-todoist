require "rails_helper"

RSpec.describe ProjectsHelper, type: :helper do
  describe "#project_tint" do
    it "returns nil for no project" do
      expect(helper.project_tint(nil)).to be_nil
    end

    it "returns a colour from the palette" do
      project = Project.create!(name: "Work")
      expect(ProjectsHelper::PROJECT_TINTS).to include(helper.project_tint(project))
    end

    it "is stable for the same name" do
      a = Project.create!(name: "Home")
      b = Project.new(name: "Home")
      expect(helper.project_tint(a)).to eq(helper.project_tint(b))
    end

    it "usually differs between projects" do
      names = %w[Alpha Beta Gamma Delta Epsilon Zeta Eta Theta]
      tints = names.map { |n| helper.project_tint(Project.new(name: n)) }
      expect(tints.uniq.size).to be >= 5
    end
  end
end
