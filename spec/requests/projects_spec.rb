require "rails_helper"

RSpec.describe "Projects", type: :request do
  describe "GET /projects" do
    it "lists project names" do
      Project.create!(name: "Work")
      get projects_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Work")
    end
  end

  describe "GET new / edit" do
    it "renders new" do
      get new_project_path
      expect(response).to have_http_status(:ok)
    end

    it "renders edit pre-filled" do
      project = Project.create!(name: "Work")
      get edit_project_path(project)
      expect(response.body).to include("Work")
    end
  end

  describe "POST /projects" do
    it "creates on valid params and redirects" do
      expect {
        post projects_path, params: { project: { name: "Home" } }
      }.to change(Project, :count).by(1)
      expect(response).to redirect_to(projects_path)
    end

    it "re-renders 422 on blank name" do
      expect {
        post projects_path, params: { project: { name: "" } }
      }.not_to change(Project, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "re-renders 422 on duplicate name" do
      Project.create!(name: "Work")
      expect {
        post projects_path, params: { project: { name: "Work" } }
      }.not_to change(Project, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /projects/:id" do
    it "updates on valid params" do
      project = Project.create!(name: "Old")
      patch project_path(project), params: { project: { name: "New" } }
      expect(project.reload.name).to eq("New")
    end

    it "re-renders 422 on invalid params" do
      project = Project.create!(name: "Old")
      patch project_path(project), params: { project: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(project.reload.name).to eq("Old")
    end
  end

  describe "DELETE /projects/:id" do
    it "removes the project and nullifies its tasks (they survive)" do
      project = Project.create!(name: "Work")
      task = Task.create!(title: "t", project: project)
      expect { delete project_path(project) }.to change(Project, :count).by(-1)
      expect(Task.exists?(task.id)).to be(true)
      expect(task.reload.project_id).to be_nil
    end
  end

  describe "a missing project" do
    it "returns 404 on edit" do
      get edit_project_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end
end
