require "rails_helper"

# Pure-CSS disclosure: a visually-hidden checkbox + a visible <label> toggle.
# Engine-independent — unlike <details>, whose closed-state some engines render
# as hidden even with display:contents, so this shows the sidebar on wide
# screens regardless of toggle state, and the menu button only at narrow widths.
RSpec.describe "Responsive nav", type: :system do
  before { driven_by(:rack_test) }

  it "renders the checkbox toggle and the nav columns" do
    visit root_path

    expect(page).to have_css("input#nav-drawer.nav-drawer-toggle[type=checkbox]")
    expect(page).to have_css("label.nav-toggle[for=nav-drawer]", text: "Menu")
    expect(page).to have_css("div.nav-sidebar.column.is-narrow")
    expect(page).to have_css("div.nav-main.column")
  end

  it "places the sidebar after the checkbox so :checked ~ .nav-sidebar applies" do
    visit root_path

    expect(page).to have_xpath(
      "//input[@id='nav-drawer']/following-sibling::div[contains(@class,'nav-sidebar')]"
    )
  end

  it "reveals the drawer only while the toggle checkbox is checked" do
    visit root_path

    expect(page.find("#nav-drawer")).not_to be_checked
    expect(page).to have_css("label.nav-toggle", text: "Menu")

    find("label.nav-toggle").click
    expect(page.find("#nav-drawer")).to be_checked

    find("label.nav-toggle").click
    expect(page.find("#nav-drawer")).not_to be_checked
  end

  it "keeps every nav link inside the sidebar and navigates to its page" do
    visit root_path

    within(".nav-sidebar") do
      expect(page).to have_link("Inbox")
      expect(page).to have_link("Overdue")
      expect(page).to have_link("Today")
      expect(page).to have_link("Upcoming")
      expect(page).to have_link("Completed")
      expect(page).to have_link("New task")
      expect(page).to have_link("Manage projects")
      expect(page).to have_link("Manage labels")
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
      within(".nav-sidebar") { click_link label }
      expect(page).to have_current_path(path, ignore_query: true)
    end
  end

  it "renders the drawer closed on the freshly loaded page after navigation" do
    visit root_path
    expect(page.find("#nav-drawer")).not_to be_checked

    within(".nav-sidebar") { click_link "Today" }
    expect(page).to have_current_path(today_tasks_path)
    expect(page.find("#nav-drawer")).not_to be_checked
  end
end
