require "rails_helper"

RSpec.describe "Login flow", type: :system, signed_out: true do
  before { driven_by(:rack_test) }

  it "logs in from the login form and logs out from the navbar" do
    User.create!(email_address: "me@example.com", password: "secret-password")

    visit root_path
    expect(page).to have_button("Sign in")
    expect(page).to have_no_link("Inbox")

    fill_in "email_address", with: "me@example.com"
    fill_in "password", with: "secret-password"
    click_button "Sign in"
    expect(page).to have_link("Inbox")

    click_button "Log out"
    expect(page).to have_button("Sign in")
  end
end
