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

  describe "optional due time" do
    around do |example|
      travel_to(Time.zone.local(2026, 2, 10, 12, 0, 0)) { example.run }
    end

    it "composes due_at from date + time and is not all_day" do
      task = Task.new(title: "t", due_date: "2026-02-20", due_time: "14:30")
      task.valid?
      expect(task.due_at).to eq(Time.zone.local(2026, 2, 20, 14, 30))
      expect(task.all_day?).to eq(false)
    end

    it "composes due_at as beginning of day and is all_day when time omitted" do
      task = Task.new(title: "t", due_date: "2026-02-20")
      task.valid?
      expect(task.due_at).to eq(Time.zone.local(2026, 2, 20).beginning_of_day)
      expect(task.all_day?).to eq(true)
    end

    it "reflects due_at in due_date and due_time readers when not explicitly assigned" do
      task = Task.create!(title: "t", due_at: Time.zone.local(2026, 2, 20, 9, 15))
      expect(task.due_date).to eq("2026-02-20")
      expect(task.due_time).to eq("09:15")

      all_day_task = Task.create!(title: "t", due_at: Time.zone.local(2026, 2, 20).beginning_of_day, all_day: true)
      expect(all_day_task.due_time).to be_nil
    end

    it "clears due_at and all_day when due_date is set blank" do
      task = Task.create!(title: "t", due_at: Time.zone.local(2026, 2, 20, 9, 15))
      task.due_date = ""
      task.valid?
      expect(task.due_at).to be_nil
      expect(task.all_day?).to eq(false)
    end

    it "leaves compose logic untouched when due_at is set directly" do
      task = Task.create!(title: "t", due_at: Time.zone.local(2026, 2, 20, 9, 15))
      expect(task.all_day?).to eq(false)
      expect(task.due_at).to eq(Time.zone.local(2026, 2, 20, 9, 15))
    end
  end

  describe "date views (slice 3)" do
    around do |example|
      travel_to(Time.zone.local(2026, 1, 15, 12, 0, 0)) { example.run }
    end

    describe ".due_today_or_undated" do
      it "matches overdue, due-today, and undated tasks; excludes due-tomorrow" do
        overdue = Task.create!(title: "overdue", due_at: 1.day.ago)
        due_today = Task.create!(title: "due today", due_at: Time.current)
        undated = Task.create!(title: "undated")
        due_tomorrow = Task.create!(title: "due tomorrow", due_at: 1.day.from_now)

        expect(Task.due_today_or_undated).to contain_exactly(overdue, due_today, undated)
        expect(Task.due_today_or_undated).not_to include(due_tomorrow)
      end
    end

    describe ".due_between" do
      it "matches only tasks due within the given range" do
        range = 1.day.from_now.beginning_of_day..7.days.from_now.end_of_day

        due_tomorrow = Task.create!(title: "tomorrow", due_at: 1.day.from_now)
        due_today = Task.create!(title: "today", due_at: Time.current)
        due_day_8 = Task.create!(title: "day 8", due_at: 8.days.from_now)
        undated = Task.create!(title: "undated")

        result = Task.due_between(range)
        expect(result).to include(due_tomorrow)
        expect(result).not_to include(due_today, due_day_8, undated)
      end
    end
  end
end
