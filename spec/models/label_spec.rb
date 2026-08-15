require "rails_helper"

RSpec.describe Label, type: :model do
  it "is invalid without a name" do
    expect(Label.new(name: nil)).not_to be_valid
  end

  it "is invalid with a duplicate name" do
    Label.create!(name: "urgent")
    expect(Label.new(name: "urgent")).not_to be_valid
  end

  it "treats names case-insensitively for uniqueness" do
    Label.create!(name: "urgent")
    expect(Label.new(name: "Urgent")).not_to be_valid
  end

  it "strips surrounding whitespace and rejects the trimmed duplicate" do
    label = Label.create!(name: "  urgent  ")
    expect(label.name).to eq("urgent")
    expect(Label.new(name: "urgent ")).not_to be_valid
  end

  it "enforces case-insensitive uniqueness at the database level" do
    Label.create!(name: "urgent")
    expect {
      Label.new(name: "Urgent").save(validate: false)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "removes its join rows on delete but keeps the tasks" do
    label = Label.create!(name: "urgent")
    task = Task.create!(title: "t", labels: [ label ])

    label.destroy

    expect(Task.exists?(task.id)).to be(true)
    expect(TaskLabel.where(label_id: label.id)).to be_empty
  end
end
