# Every request/system example runs signed in, so existing specs need no
# login setup. Tag an example group `signed_out: true` to opt out.
module AuthenticationHelpers
  PASSWORD = "secret-password".freeze

  def self.create_user
    User.create!(email_address: "me@example.com", password: PASSWORD)
  end

  module Request
    def sign_in_as(user)
      post session_path, params: { email_address: user.email_address, password: PASSWORD }
    end
  end

  module System
    def sign_in_as(user)
      visit new_session_path
      fill_in "email_address", with: user.email_address
      fill_in "password", with: PASSWORD
      click_button "Sign in"
    end
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers::Request, type: :request
  config.include AuthenticationHelpers::System, type: :system

  config.before do |example|
    next if example.metadata[:signed_out] || !%i[ request system ].include?(example.metadata[:type])

    sign_in_as(AuthenticationHelpers.create_user)
  end
end
