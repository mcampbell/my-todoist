require "rails_helper"

RSpec.describe "Authentication", type: :request, signed_out: true do
  let!(:user) { User.create!(email_address: "me@example.com", password: "secret-password") }

  def log_in(password: "secret-password")
    post session_path, params: { email_address: "me@example.com", password: password }
  end

  describe "signed out" do
    it "redirects pages to the login form" do
      get root_path
      expect(response).to redirect_to(new_session_path)
    end

    it "answers the due-reminder poll with 401, not a login redirect" do
      get due_since_tasks_path(format: :json), params: { since: Time.current.iso8601 }
      expect(response).to have_http_status(:unauthorized)
    end

    # The poll runs on the login page too; it must not become the
    # post-login destination.
    it "returns to root after login when only the poll ran" do
      get due_since_tasks_path(format: :json), params: { since: Time.current.iso8601 }
      log_in
      expect(response).to redirect_to(root_url)
    end

    it "returns to the page first asked for after login" do
      get today_tasks_path
      log_in
      expect(response).to redirect_to(today_tasks_url)
    end

    it "shows the login form" do
      get new_session_path
      expect(response).to have_http_status(:ok)
    end
  end

  it "logs in with the right password" do
    log_in
    expect(response).to redirect_to(root_url)
    get root_path
    expect(response).to have_http_status(:ok)
  end

  # A generic "session_id" would clash with other apps on the same host.
  it "uses an app-specific login cookie name" do
    log_in
    expect(cookies[:todo_session_id]).to be_present
    expect(cookies[:session_id]).to be_nil
  end

  it "rejects a wrong password" do
    log_in(password: "wrong")
    expect(response).to redirect_to(new_session_path)
    expect(Session.count).to eq(0)
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "logs out and ends the session" do
    log_in
    delete session_path
    expect(Session.count).to eq(0)
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "rate-limits login attempts" do
    10.times { log_in(password: "wrong") }
    log_in
    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to eq("Try again later.")
  end
end
