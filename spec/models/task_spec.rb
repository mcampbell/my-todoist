require "rails_helper"

RSpec.describe Task, type: :model do
  it "is invalid without a title" do
    expect(Task.new(title: nil)).not_to be_valid
  end

  describe "#complete! (occurrence-log completion)" do
    it "destroys the task and creates a matching CompletedOccurrence" do
      project = Project.create!(name: "Work")
      label_b = Label.create!(name: "b")
      label_a = Label.create!(name: "a")
      task = Task.create!(
        title: "t", project: project, priority: 2, labels: [ label_b, label_a ],
        due_at: Time.zone.local(2030, 3, 4, 9, 30)
      )

      expect { task.complete! }.to change(Task, :count).by(-1)
        .and change(CompletedOccurrence, :count).by(1)

      occurrence = CompletedOccurrence.last
      expect(occurrence.task_title).to eq("t")
      expect(occurrence.project_name).to eq("Work")
      expect(occurrence.priority).to eq(2)
      expect(occurrence.label_names).to eq("a, b")
      expect(occurrence.due_at).to eq(Time.zone.local(2030, 3, 4, 9, 30))
      expect(occurrence.completed_at).to be_present
    end

    it "snapshots the all_day flag when completing" do
      all_day = Task.create!(title: "all-day", due_at: Time.zone.local(2030, 3, 4).beginning_of_day, all_day: true)
      all_day.complete!
      expect(CompletedOccurrence.last.all_day?).to eq(true)

      timed = Task.create!(title: "timed", due_at: Time.zone.local(2030, 3, 4, 9, 30), all_day: false)
      timed.complete!
      expect(CompletedOccurrence.order(:id).last.all_day?).to eq(false)
    end

    it "raises RecordNotFound when the same id is completed a second time" do
      task = Task.create!(title: "t")
      task.complete!
      expect { Task.find(task.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "keeps a recurring task active and advances its due_at (fixed weekly)" do
      # every wednesday, due 2026-01-28, completed Saturday 2026-02-07 -> 2026-02-11.
      travel_to(Time.zone.local(2026, 2, 7, 12, 0, 0)) do
        task = Task.create!(title: "meeting", recurrence: "every wednesday",
                            due_at: Time.zone.local(2026, 1, 28, 12, 0, 0))
        task.complete!
        expect(Task.count).to eq(1)
        expect(CompletedOccurrence.count).to eq(1)
        task.reload
        expect(task.recurrence).to eq("every wednesday")
        expect(task.due_at).to eq(Time.zone.local(2026, 2, 11, 12, 0, 0))
      end
    end

    it "advances a fixed N-days recurring task in whole intervals (worked example)" do
      # every 3 days, due 2026-02-02, completed 2026-02-10 -> 2026-02-11 (1 day out).
      travel_to(Time.zone.local(2026, 2, 10, 12, 0, 0)) do
        task = Task.create!(title: "pills", recurrence: "every 3 days",
                            due_at: Time.zone.local(2026, 2, 2, 12, 0, 0))
        task.complete!
        task.reload
        expect(task.due_at).to eq(Time.zone.local(2026, 2, 11, 12, 0, 0))
      end
    end

    it "keeps a rolling all-day task all-day, landing at midnight on the completion-advanced date" do
      travel_to(Time.zone.local(2026, 2, 10, 10, 0, 0)) do
        task = Task.create!(title: "pill", recurrence: "every! day",
                            due_at: Time.zone.local(2026, 2, 10).beginning_of_day, all_day: true)
        task.complete!
        task.reload
        expect(task.all_day?).to eq(true)
        expect(task.due_at).to eq(Time.zone.local(2026, 2, 11).beginning_of_day)
      end
    end

    it "does not stall on a sub-day rolling recurrence attached to an all-day task" do
      travel_to(Time.zone.local(2026, 2, 10, 10, 0, 0)) do
        task = Task.create!(title: "pill", recurrence: "every! 5 minutes",
                            due_at: Time.zone.local(2026, 2, 10).beginning_of_day, all_day: true)
        task.complete!
        task.reload
        expect(task.all_day?).to eq(false)
        expect(task.due_at).to eq(Time.zone.local(2026, 2, 10, 10, 5, 0))
      end
    end

    it "keeps a fixed all-day recurrence all-day when due stays at midnight" do
      travel_to(Time.zone.local(2026, 2, 10, 10, 0, 0)) do
        task = Task.create!(title: "pill", recurrence: "every day",
                            due_at: Time.zone.local(2026, 2, 10).beginning_of_day, all_day: true)
        task.complete!
        task.reload
        expect(task.all_day?).to eq(true)
        expect(task.due_at).to eq(Time.zone.local(2026, 2, 11).beginning_of_day)
      end
    end

    it "keeps a fixed month-unit all-day recurrence all-day" do
      travel_to(Time.zone.local(2026, 2, 10, 10, 0, 0)) do
        task = Task.create!(title: "rent", recurrence: "every month",
                            due_at: Time.zone.local(2026, 2, 1).beginning_of_day, all_day: true)
        task.complete!
        task.reload
        expect(task.all_day?).to eq(true)
        expect(task.due_at).to eq(Time.zone.local(2026, 3, 1).beginning_of_day)
      end
    end

    it "keeps a rolling month-unit all-day recurrence all-day" do
      travel_to(Time.zone.local(2026, 2, 10, 10, 0, 0)) do
        task = Task.create!(title: "rent", recurrence: "every! month",
                            due_at: Time.zone.local(2026, 2, 1).beginning_of_day, all_day: true)
        task.complete!
        task.reload
        expect(task.all_day?).to eq(true)
        expect(task.due_at).to eq(Time.zone.local(2026, 3, 1).beginning_of_day)
      end
    end
      it "advances a rolling recurring task from the completion time" do
      travel_to(Time.zone.local(2026, 2, 10, 12, 0, 0)) do
        task = Task.create!(title: "pills", recurrence: "every! 6 hours",
                            due_at: Time.zone.local(2026, 2, 10, 8, 0))
        task.complete!
        task.reload
        expect(task.due_at).to eq(Time.zone.local(2026, 2, 10, 18, 0))
      end
    end

    it "snapshots the occurrence even for a recurring task" do
      travel_to(Time.zone.local(2026, 2, 10, 12, 0, 0)) do
        task = Task.create!(title: "pills", recurrence: "every day",
                            due_at: Time.zone.local(2026, 2, 10, 12, 0))
        task.complete!
        occurrence = CompletedOccurrence.last
        expect(occurrence.task_title).to eq("pills")
        expect(occurrence.due_at).to eq(Time.zone.local(2026, 2, 10, 12, 0))
        expect(occurrence.completed_at).to be_present
      end
    end

    context "when the next occurrence was rescheduled off the pattern" do
      it "steps the pattern from recurrence_anchor_at, not the moved due_at" do
        # every wednesday, real phase Wed 2026-01-28 12:00; the next occurrence
        # was moved to Sat 2026-01-31; completing it must land back on Wednesday.
        travel_to(Time.zone.local(2026, 1, 31, 12, 0, 0)) do
          task = Task.create!(
            title: "meeting", recurrence: "every wednesday",
            due_at: Time.zone.local(2026, 1, 31, 15, 0, 0), all_day: false,
            recurrence_anchor_at: Time.zone.local(2026, 1, 28, 12, 0, 0),
            recurrence_anchor_all_day: false
          )
          task.complete!
          task.reload
          expect(task.due_at).to eq(Time.zone.local(2026, 2, 4, 12, 0, 0))
          expect(task.recurrence_anchor_at).to be_nil
          expect(task.recurrence_anchor_all_day).to be_nil
        end
      end

      it "restores the pattern's all-day state from recurrence_anchor_all_day" do
        # all-day weekly task whose next occurrence was rescheduled to a timed slot.
        travel_to(Time.zone.local(2026, 2, 5, 12, 0, 0)) do
          task = Task.create!(
            title: "bins", recurrence: "every week",
            due_at: Time.zone.local(2026, 2, 5, 15, 0, 0), all_day: false,
            recurrence_anchor_at: Time.zone.local(2026, 2, 2).beginning_of_day,
            recurrence_anchor_all_day: true
          )
          task.complete!
          task.reload
          expect(task.all_day?).to eq(true)
          expect(task.due_at).to eq(Time.zone.local(2026, 2, 9).beginning_of_day)
          expect(task.recurrence_anchor_at).to be_nil
        end
      end
    end
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

    describe ".overdue" do
      it "matches only tasks due before today" do
        overdue = Task.create!(title: "overdue", due_at: 1.day.ago)
        due_today = Task.create!(title: "due today", due_at: Time.current)
        undated = Task.create!(title: "undated")

        expect(Task.overdue).to contain_exactly(overdue)
        expect(Task.overdue).not_to include(due_today, undated)
      end

      it "includes a timed task whose time has passed today" do
        timed_past = Task.create!(title: "timed past", due_at: 1.hour.ago, all_day: false)
        timed_future = Task.create!(title: "timed future", due_at: 1.hour.from_now, all_day: false)
        all_day_today = Task.create!(title: "all day today", due_at: Time.current.beginning_of_day, all_day: true)

        expect(Task.overdue).to include(timed_past)
        expect(Task.overdue).not_to include(timed_future, all_day_today)
      end
    end

    describe "#overdue?" do
      it "is true only for a task due before today" do
        overdue = Task.create!(title: "overdue", due_at: 1.day.ago)
        due_today = Task.create!(title: "due today", due_at: Time.current)
        undated = Task.create!(title: "undated")

        expect(overdue.overdue?).to eq(true)
        expect(due_today.overdue?).to eq(false)
        expect(undated.overdue?).to eq(false)
      end

      it "is true for a timed task once its time has passed today" do
        timed_past = Task.create!(title: "timed past", due_at: 1.hour.ago, all_day: false)
        timed_future = Task.create!(title: "timed future", due_at: 1.hour.from_now, all_day: false)

        expect(timed_past.overdue?).to eq(true)
        expect(timed_future.overdue?).to eq(false)
      end

      it "is false for an all-day task due today regardless of time of day" do
        all_day_today = Task.create!(title: "all day today", due_at: Time.current.beginning_of_day, all_day: true)

        expect(all_day_today.overdue?).to eq(false)
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

  describe "#skip! (advance to next occurrence without logging completion)" do
    it "advances a recurring task's due_at without creating a CompletedOccurrence" do
      travel_to(Time.zone.local(2026, 2, 7, 12, 0, 0)) do
        task = Task.create!(title: "meeting", recurrence: "every wednesday",
                            due_at: Time.zone.local(2026, 1, 28, 12, 0, 0))
        expect { task.skip! }.not_to change(CompletedOccurrence, :count)
        task.reload
        expect(Task.count).to eq(1)
        expect(task.due_at).to eq(Time.zone.local(2026, 2, 11, 12, 0, 0))
      end
    end

    it "clears a stale reschedule anchor, same as completing" do
      travel_to(Time.zone.local(2026, 2, 7, 12, 0, 0)) do
        task = Task.create!(title: "meeting", recurrence: "every wednesday",
                            due_at: Time.zone.local(2026, 2, 4, 12, 0, 0),
                            recurrence_anchor_at: Time.zone.local(2026, 1, 28, 12, 0, 0),
                            recurrence_anchor_all_day: false)
        task.skip!
        task.reload
        expect(task.recurrence_anchor_at).to be_nil
        expect(task.recurrence_anchor_all_day).to be_nil
      end
    end

    it "raises for a task with no recurrence" do
      task = Task.create!(title: "one-off")
      expect { task.skip! }.to raise_error(ArgumentError)
    end
  end
end
