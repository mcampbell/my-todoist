require "rails_helper"
require "rake"

RSpec.describe "rake user:create" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("user:create") }

  around do |example|
    saved = ENV.to_h.slice("EMAIL", "PASSWORD")
    example.run
  ensure
    ENV.delete("EMAIL")
    ENV.delete("PASSWORD")
    ENV.update(saved)
  end

  def run_task
    Rake::Task["user:create"].reenable
    Rake::Task["user:create"].invoke
  end

  it "creates the user from EMAIL and PASSWORD" do
    ENV["EMAIL"] = "me@example.com"
    ENV["PASSWORD"] = "secret-password"

    expect { run_task }.to output(/me@example.com/).to_stdout
    expect(User.authenticate_by(email_address: "me@example.com", password: "secret-password")).to be_present
  end

  it "fails loudly without PASSWORD" do
    ENV["EMAIL"] = "me@example.com"
    ENV.delete("PASSWORD")

    expect { run_task }.to raise_error(KeyError)
    expect(User.count).to eq(0)
  end
end
