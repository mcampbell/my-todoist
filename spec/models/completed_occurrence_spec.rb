require "rails_helper"

RSpec.describe CompletedOccurrence, type: :model do
  it "is valid with task_title, priority, and completed_at" do
    occurrence = CompletedOccurrence.new(task_title: "t", priority: 0, completed_at: Time.current)
    expect(occurrence).to be_valid
  end

  it "is invalid without task_title" do
    expect(CompletedOccurrence.new(task_title: nil, priority: 0, completed_at: Time.current)).not_to be_valid
  end

  it "is invalid without priority" do
    expect(CompletedOccurrence.new(task_title: "t", priority: nil, completed_at: Time.current)).not_to be_valid
  end

  it "is invalid without completed_at" do
    expect(CompletedOccurrence.new(task_title: "t", priority: 0, completed_at: nil)).not_to be_valid
  end
end
