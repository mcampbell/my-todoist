require "rails_helper"

RSpec.describe Task, type: :model do
  it "is invalid without a title" do
    expect(Task.new(title: nil)).not_to be_valid
  end

  it "partitions rows into active and completed scopes" do
    active = Task.create!(title: "active")
    done = Task.create!(title: "done", completed_at: Time.current)

    expect(Task.active).to contain_exactly(active)
    expect(Task.completed).to contain_exactly(done)
  end

  it "sets completed_at and flips completed? on complete!" do
    task = Task.create!(title: "t")
    expect { task.complete! }.to change(task, :completed?).from(false).to(true)
    expect(task.completed_at).to be_present
  end

  it "keeps the original completed_at when complete! runs twice" do
    task = Task.create!(title: "t")
    task.complete!
    first = task.completed_at
    task.complete!
    expect(task.reload.completed_at).to eq(first)
  end

  it "keeps the first completed_at when two stale copies both complete!" do
    task = Task.create!(title: "t")
    copy_a = Task.find(task.id)
    copy_b = Task.find(task.id)

    copy_a.complete!
    first = copy_a.reload.completed_at
    copy_b.complete! # stale: still sees completed_at nil in memory

    expect(task.reload.completed_at).to eq(first)
  end

  describe "organization (slice 2)" do
    it "is valid with no project (Inbox) — proves belongs_to optional" do
      expect(Task.new(title: "inbox")).to be_valid
    end

    it "belongs to a project and appears in project.tasks" do
      project = Project.create!(name: "Work")
      task = Task.create!(title: "t", project: project)
      expect(task.project).to eq(project)
      expect(project.tasks).to include(task)
    end

    it "associates labels via label_ids" do
      a = Label.create!(name: "a")
      b = Label.create!(name: "b")
      task = Task.create!(title: "t", label_ids: [ a.id, b.id ])
      expect(task.labels).to contain_exactly(a, b)
    end

    it "defaults priority to 0" do
      expect(Task.create!(title: "t").priority).to eq(0)
    end

    it "accepts priority 0..3 and rejects outside that range" do
      expect(Task.new(title: "t", priority: 3)).to be_valid
      expect(Task.new(title: "t", priority: 5)).not_to be_valid
      expect(Task.new(title: "t", priority: -1)).not_to be_valid
    end

    it "keeps NULLS LAST + created_at DESC in the ordered scope" do
      no_due = Task.create!(title: "no-due")
      tomorrow = Task.create!(title: "tomorrow", due_at: 1.day.from_now)
      today = Task.create!(title: "today", due_at: Time.current)
      expect(Task.ordered.to_a).to eq([ today, tomorrow, no_due ])
    end
  end
end
