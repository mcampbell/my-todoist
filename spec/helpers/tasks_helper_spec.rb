require "rails_helper"

RSpec.describe TasksHelper, type: :helper do
  describe "#overdue_class" do
    let(:now) { Time.zone.local(2030, 3, 15, 12, 0) }

    def class_for(due_at, all_day: false)
      travel_to(now) { helper.overdue_class(Task.new(title: "t", due_at: due_at, all_day: all_day)) }
    end

    it "returns nil for a task that is not overdue" do
      expect(class_for(1.hour.since(now))).to be_nil
      expect(class_for(nil)).to be_nil
    end

    it "uses the light shade when overdue by under a week" do
      expect(class_for(1.minute.until(now))).to eq("has-background-danger-light")
      expect(class_for(1.second.since(1.week.until(now)))).to eq("has-background-danger-light")
    end

    it "uses the middle shade from one week up to one month" do
      expect(class_for(1.week.until(now))).to eq("has-background-danger-85")
      expect(class_for(1.second.since(1.month.until(now)))).to eq("has-background-danger-85")
    end

    it "uses the darkest shade from one month on" do
      expect(class_for(1.month.until(now))).to eq("has-background-danger-80")
      expect(class_for(1.year.until(now))).to eq("has-background-danger-80")
    end

    it "ages an all-day task from its due date's midnight" do
      due = 1.week.until(now).beginning_of_day
      expect(class_for(due, all_day: true)).to eq("has-background-danger-85")
    end
  end

  describe "#format_time" do
    it "omits the year when the time is in the current year" do
      travel_to(Time.zone.local(2030, 1, 1)) do
        expect(helper.format_time(Time.zone.local(2030, 6, 5, 14, 30))).to eq("Jun 5, 2:30 PM")
      end
    end

    it "includes the year when the time is not in the current year" do
      travel_to(Time.zone.local(2026, 1, 1)) do
        expect(helper.format_time(Time.zone.local(2030, 6, 5, 14, 30))).to eq("Jun 5, 2030, 2:30 PM")
      end
    end

    it "returns nil for a nil time" do
      expect(helper.format_time(nil)).to be_nil
    end
  end

  describe "#due_tag" do
    it "omits the year on an all-day task in the current year" do
      travel_to(Time.zone.local(2030, 1, 1)) do
        task = Task.new(title: "t", all_day: true, due_at: Time.zone.local(2030, 6, 5))
        expect(helper.due_tag(task)).to eq("Jun 5")
      end
    end

    it "includes the year on an all-day task not in the current year" do
      travel_to(Time.zone.local(2026, 1, 1)) do
        task = Task.new(title: "t", all_day: true, due_at: Time.zone.local(2030, 6, 5))
        expect(helper.due_tag(task)).to eq("Jun 5, 2030")
      end
    end

    it "includes the year on a timed task not in the current year" do
      travel_to(Time.zone.local(2026, 1, 1)) do
        task = Task.new(title: "t", all_day: false, due_at: Time.zone.local(2030, 6, 5, 14, 30))
        expect(helper.due_tag(task)).to eq("Jun 5, 2030, 2:30 PM")
      end
    end

    it "returns nil when the task has no due_at" do
      expect(helper.due_tag(Task.new(title: "t"))).to be_nil
    end
  end

  describe "#priority_label" do
    it "inverts the stored integer to the p1..p4 input convention" do
      expect([ 3, 2, 1, 0 ].map { |stored| helper.priority_label(stored) })
        .to eq([ 1, 2, 3, 4 ])
    end
  end

  describe "#priority_badge" do
    it "renders a colored tag for p1..p3" do
      task = Task.new(title: "t", priority: 3)
      expect(helper.priority_badge(task)).to include("P1").and include("is-danger")
    end

    it "renders nothing for p4 (stored 0), the baseline priority" do
      task = Task.new(title: "t", priority: 0)
      expect(helper.priority_badge(task)).to be_nil
    end
  end

  describe "#priority_select_options" do
    it "lists p1..p4 in urgent-first order, each mapped to its stored integer" do
      expect(helper.priority_select_options).to eq([ [ "P1", 3 ], [ "P2", 2 ], [ "P3", 1 ], [ "P4", 0 ] ])
    end
  end

  describe "#notes_preview" do
    it "returns nil when there are no notes" do
      expect(helper.notes_preview(nil)).to be_nil
    end

    it "returns nil when the notes are blank" do
      expect(helper.notes_preview("   \n ")).to be_nil
    end

    it "returns a single-line note unchanged" do
      expect(helper.notes_preview("Call the plumber")).to eq("Call the plumber")
    end

    it "keeps only the first line and marks the cut with an ellipsis" do
      expect(helper.notes_preview("Call the plumber\nAsk about the sink")).to eq("Call the plumber...")
    end

    # A browser submits a textarea with CRLF line endings, so the parser must
    # not leave a stray carriage return at the end of the preview.
    it "handles the CRLF line endings a browser submits" do
      expect(helper.notes_preview("Call the plumber\r\nAsk about the sink")).to eq("Call the plumber...")
    end

    it "ignores trailing blank lines when deciding to add an ellipsis" do
      expect(helper.notes_preview("Call the plumber\n\n  ")).to eq("Call the plumber")
    end
  end

  describe "#linkify" do
    def links(html)
      Capybara.string(html).all("a").map { |a| [ a.text, a[:href] ] }
    end

    it "returns text without a URL unchanged" do
      expect(helper.linkify("Call the plumber")).to eq("Call the plumber")
    end

    it "returns an empty string for nil or empty text" do
      expect([ helper.linkify(nil), helper.linkify("") ]).to eq([ "", "" ])
    end

    it "links each http and https URL, opening it in a new tab" do
      html = helper.linkify("See http://a.example/x and https://b.example/y?q=1&r=2")
      expect(links(html)).to eq([ [ "http://a.example/x", "http://a.example/x" ],
                                  [ "https://b.example/y?q=1&r=2", "https://b.example/y?q=1&r=2" ] ])
      link = Capybara.string(html).first("a")
      expect(link[:target]).to eq("_blank")
      expect(link[:rel]).to eq("noopener noreferrer")
    end

    it "keeps sentence punctuation after a URL out of the link" do
      html = helper.linkify("Read https://a.example/x. Then (https://b.example/y), done")
      expect(links(html).map(&:last)).to eq([ "https://a.example/x", "https://b.example/y" ])
      expect(Capybara.string(html).text).to eq("Read https://a.example/x. Then (https://b.example/y), done")
    end

    it "links a URL at the end of a preview without the ellipsis" do
      expect(links(helper.linkify("https://a.example/x..."))).to eq([ [ "https://a.example/x", "https://a.example/x" ] ])
    end

    # A phone auto-capitalizes the first word of a title.
    it "links a scheme in any case" do
      expect(links(helper.linkify("Https://a.example/x"))).to eq([ [ "Https://a.example/x", "Https://a.example/x" ] ])
    end

    it "does not link other schemes or a bare scheme" do
      expect(links(helper.linkify("javascript:alert(1) ftp://a.example xhttps://a.example https://"))).to be_empty
    end

    it "escapes HTML in the text and in the URL" do
      html = helper.linkify(%(<b>hi</b> https://a.example/<script>))
      expect(html).to include("&lt;b&gt;hi&lt;/b&gt;")
      expect(html).not_to include("<script>")
      expect(links(html)).to eq([ [ "https://a.example/", "https://a.example/" ] ])
    end

    it "passes each non-URL part through the block" do
      html = helper.linkify("Read https://a.example/x now") { |text| tag.em(text) }
      expect(Capybara.string(html).all("em").map(&:text)).to eq([ "Read ", " now" ])
    end

    # A title that is only a URL must not grow an empty edit link before it.
    it "does not pass empty text to the block around a URL" do
      html = helper.linkify("https://a.example/x") { |text| tag.em(text) }
      expect(Capybara.string(html)).to have_no_css("em")
    end
  end
end
