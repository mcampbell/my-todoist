require "rails_helper"

RSpec.describe "Labels", type: :request do
  describe "GET /labels" do
    it "lists label names" do
      Label.create!(name: "urgent")
      get labels_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("urgent")
    end
  end

  describe "GET new / edit" do
    it "renders new" do
      get new_label_path
      expect(response).to have_http_status(:ok)
    end

    it "renders edit pre-filled" do
      label = Label.create!(name: "urgent")
      get edit_label_path(label)
      expect(response.body).to include("urgent")
    end
  end

  describe "POST /labels" do
    it "creates on valid params and redirects" do
      expect {
        post labels_path, params: { label: { name: "home" } }
      }.to change(Label, :count).by(1)
      expect(response).to redirect_to(labels_path)
    end

    it "re-renders 422 on blank name" do
      expect {
        post labels_path, params: { label: { name: "" } }
      }.not_to change(Label, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "re-renders 422 on duplicate name" do
      Label.create!(name: "urgent")
      expect {
        post labels_path, params: { label: { name: "urgent" } }
      }.not_to change(Label, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /labels/:id" do
    it "updates on valid params" do
      label = Label.create!(name: "old")
      patch label_path(label), params: { label: { name: "new" } }
      expect(label.reload.name).to eq("new")
    end

    it "re-renders 422 on invalid params" do
      label = Label.create!(name: "old")
      patch label_path(label), params: { label: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(label.reload.name).to eq("old")
    end
  end

  describe "DELETE /labels/:id" do
    it "removes the label and its join rows but keeps the tasks" do
      label = Label.create!(name: "urgent")
      task = Task.create!(title: "t", labels: [ label ])
      expect { delete label_path(label) }.to change(Label, :count).by(-1)
      expect(Task.exists?(task.id)).to be(true)
      expect(TaskLabel.where(label_id: label.id)).to be_empty
    end
  end

  describe "a missing label" do
    it "returns 404 on edit" do
      get edit_label_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end
end
