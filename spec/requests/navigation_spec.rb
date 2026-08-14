require "rails_helper"

RSpec.describe "Navigation", type: :request do
  it "renders the navbar with Tasks and Completed links" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(tasks_path)
    expect(response.body).to include(completed_tasks_path)
    expect(response.body).to include("My Todoist")
  end

  it "serves the vendored Bulma stylesheet" do
    get root_path
    expect(response.body).to match(/bulma\.min[-.]/)
  end

  it "keeps the nav menu visible at every width (no burger to toggle)" do
    get root_path
    expect(Capybara.string(response.body)).to have_css(".navbar-menu.is-active")
  end
end
