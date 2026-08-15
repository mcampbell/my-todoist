require "rails_helper"

RSpec.describe Project, type: :model do
  it "is invalid without a name" do
    expect(Project.new(name: nil)).not_to be_valid
  end

  it "is invalid with a duplicate name" do
    Project.create!(name: "Work")
    expect(Project.new(name: "Work")).not_to be_valid
  end

  it "treats names case-insensitively for uniqueness" do
    Project.create!(name: "Work")
    expect(Project.new(name: "work")).not_to be_valid
  end

  it "strips surrounding whitespace and rejects the trimmed duplicate" do
    project = Project.create!(name: "  Work  ")
    expect(project.name).to eq("Work")
    expect(Project.new(name: "Work ")).not_to be_valid
  end

  it "enforces case-insensitive uniqueness at the database level" do
    Project.create!(name: "Work")
    expect {
      Project.new(name: "work").save(validate: false)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "nullifies its tasks' project on delete (tasks survive, land in Inbox)" do
    project = Project.create!(name: "Work")
    task = Task.create!(title: "t", project: project)

    project.destroy

    expect(Task.exists?(task.id)).to be(true)
    expect(task.reload.project_id).to be_nil
  end
end
