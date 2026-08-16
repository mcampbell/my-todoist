require "rails_helper"

# rack_test driver: no JS, no CSS rendering — matches spec/system/* conventions.
# NOTE: rack_test marks any non-<summary> element inside a closed <details> as
# hidden (capybara/node/simple.rb), with no awareness of our `display: contents`
# override that exposes the content. Structural/link assertions therefore bypass
# its visibility filter with `visible: :all`. Real-browser rendering (wide-screen
# nav inline, mobile drawer, <details> disclosure) is deferred to manual testing
# per specs/responsive-nav-collapse-design.md; verified at 1280px in Chromium:
# 10/10 sidebar links visible, toggle display:none, sidebar rect 24x534.
RSpec.describe "Responsive nav", type: :system do
  before { driven_by(:rack_test) }

  it "renders drawer markup with class hooks for the media queries (plan items 1-2)" do
    visit root_path

    expect(page).to have_css("details#nav-drawer.nav-drawer")
    within("details#nav-drawer") do
      expect(page).to have_css("summary.nav-toggle", text: "Menu")
      expect(page).to have_css("div.nav-sidebar.column.is-narrow", visible: :all)
    end
    expect(page).to have_css("div.nav-main.column")
  end

  it "keeps every nav link inside the sidebar and navigates to its page" do
    visit root_path

    within(".nav-sidebar", visible: :all) do
      expect(page).to have_link("Inbox", visible: :all)
      expect(page).to have_link("Overdue", visible: :all)
      expect(page).to have_link("Today", visible: :all)
      expect(page).to have_link("Upcoming", visible: :all)
      expect(page).to have_link("Completed", visible: :all)
      expect(page).to have_link("New task", visible: :all)
      expect(page).to have_link("Manage projects", visible: :all)
      expect(page).to have_link("Manage labels", visible: :all)
    end

    {
      "Inbox" => root_path,
      "Overdue" => overdue_tasks_path,
      "Today" => today_tasks_path,
      "Upcoming" => upcoming_tasks_path,
      "Completed" => completed_tasks_path,
      "New task" => new_task_path,
      "Manage projects" => projects_path,
      "Manage labels" => labels_path
    }.each do |label, path|
      within(".nav-sidebar", visible: :all) { click_link label, visible: :all }
      expect(page).to have_current_path(path, ignore_query: true)
    end
  end

  it "renders the drawer closed on the freshly loaded page after navigation" do
    visit root_path
    expect(page).to have_css("details#nav-drawer:not([open])")

    click_link "Today", visible: :all
    expect(page).to have_current_path(today_tasks_path)
    expect(page).to have_css("details#nav-drawer:not([open])")
  end
end
