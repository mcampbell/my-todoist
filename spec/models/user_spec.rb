require "rails_helper"

RSpec.describe User, type: :model do
  # The one password is the only gate on an internet-facing host.
  it "rejects a password shorter than 12 characters" do
    user = User.new(email_address: "me@example.com", password: "a" * 11)
    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end

  it "accepts a 12-character password" do
    expect(User.new(email_address: "me@example.com", password: "a" * 12)).to be_valid
  end
end
