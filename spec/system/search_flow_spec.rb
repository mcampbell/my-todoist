require "rails_helper"

# rack_test driver: the completed-results toggle is a plain link, so a click
# re-runs the search with the flipped setting -- no JS.
RSpec.describe "Search flow", type: :system do
  before { driven_by(:rack_test) }

  it "toggles completed results into and out of the results with one click" do
    task = Task.create!(title: "milk run")
    task.complete!

    visit search_tasks_path(q: "milk")
    expect(page).to have_no_content("milk run")

    click_link "Include completed tasks"
    expect(page).to have_content("milk run")
    expect(page).to have_current_path(search_tasks_path(q: "milk", include_completed: "1"))

    click_link "Include completed tasks"
    expect(page).to have_no_content("milk run")
  end

  it "keeps the completed toggle on when a new query is run from the Search button" do
    Task.create!(title: "milk carton").complete!
    Task.create!(title: "milk crate").complete!

    visit search_tasks_path(q: "carton")
    click_link "Include completed tasks"
    expect(page).to have_content("milk carton")

    fill_in "q", with: "crate"
    click_button "Search"
    expect(page).to have_content("milk crate")
    expect(page).to have_no_content("milk carton")
  end
end
