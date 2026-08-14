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
end
