require "rails_helper"

RSpec.describe "Navigation", type: :request do
  it "renders the sidebar with Inbox and Completed links" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(root_path)
    expect(response.body).to include(completed_tasks_path)
    expect(response.body).to include("Inbox")
  end

  it "lists existing projects linking to their task view" do
    project = Project.create!(name: "Work")
    get root_path
    expect(response.body).to include("Work")
    expect(response.body).to include(project_tasks_path(project))
  end

  it "has Manage projects and Manage labels links" do
    get root_path
    expect(response.body).to include(projects_path)
    expect(response.body).to include(labels_path)
  end

  it "serves the vendored Bulma stylesheet" do
    get root_path
    expect(response.body).to match(/bulma\.min[-.]/)
  end
end
