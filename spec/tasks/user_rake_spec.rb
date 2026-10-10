require "rails_helper"
require "rake"

RSpec.describe "rake user:*" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("user:create") }

  around do |example|
    saved = ENV.to_h.slice("EMAIL", "PASSWORD")
    example.run
  ensure
    ENV.delete("EMAIL")
    ENV.delete("PASSWORD")
    ENV.update(saved)
  end

  def run_task(name)
    Rake::Task[name].reenable
    Rake::Task[name].invoke
  end

  describe "user:create" do
    it "creates the user from EMAIL and PASSWORD" do
      ENV["EMAIL"] = "me@example.com"
      ENV["PASSWORD"] = "secret-password"

      expect { run_task("user:create") }.to output(/me@example.com/).to_stdout
      expect(User.authenticate_by(email_address: "me@example.com", password: "secret-password")).to be_present
    end

    it "fails loudly without PASSWORD" do
      ENV["EMAIL"] = "me@example.com"
      ENV.delete("PASSWORD")

      expect { run_task("user:create") }.to raise_error(KeyError)
      expect(User.count).to eq(0)
    end
  end

  describe "user:modify" do
    let!(:user) { User.create!(email_address: "me@example.com", password: "old-password-1") }

    it "changes the password and ends every existing login" do
      user.sessions.create!
      ENV["EMAIL"] = "me@example.com"
      ENV["PASSWORD"] = "new-password-2"

      expect { run_task("user:modify") }.to output(/me@example.com/).to_stdout
      expect(User.authenticate_by(email_address: "me@example.com", password: "new-password-2")).to eq(user)
      expect(User.authenticate_by(email_address: "me@example.com", password: "old-password-1")).to be_nil
      expect(user.sessions.count).to eq(0)
    end

    it "fails loudly for an unknown EMAIL" do
      ENV["EMAIL"] = "nobody@example.com"
      ENV["PASSWORD"] = "new-password-2"

      expect { run_task("user:modify") }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "keeps the old password and logins when the new one is too short" do
      user.sessions.create!
      ENV["EMAIL"] = "me@example.com"
      ENV["PASSWORD"] = "short"

      expect { run_task("user:modify") }.to raise_error(ActiveRecord::RecordInvalid)
      expect(User.authenticate_by(email_address: "me@example.com", password: "old-password-1")).to eq(user)
      expect(user.sessions.count).to eq(1)
    end
  end
end
