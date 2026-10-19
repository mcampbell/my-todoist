require "rails_helper"

# The browser shows due notifications itself; the server no longer pops one.
RSpec.describe "POST /os_notification", type: :request do
  it "is no longer routed" do
    expect { Rails.application.routes.recognize_path("/os_notification", method: :post) }
      .to raise_error(ActionController::RoutingError)
  end

  it "has no route helper" do
    expect(Rails.application.routes.url_helpers).not_to respond_to(:os_notification_path)
  end
end
