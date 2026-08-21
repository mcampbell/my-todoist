require "rails_helper"

RSpec.describe "POST /os_notification", type: :request do
  it "delegates to OsNotifier with the given title and message" do
    expect(OsNotifier).to receive(:notify).with(title: "Task due", message: "Buy milk")

    post os_notification_path, params: { title: "Task due", message: "Buy milk" }, as: :json
    expect(response).to have_http_status(:no_content)
  end
end
