require "rails_helper"

RSpec.describe "Midnight refresh", type: :request do
  it "renders the seconds-until-midnight meta tag for the client reload timer" do
    get tasks_path
    expect(response.body).to match(/<meta name="seconds-until-midnight" content="\d+">/)
  end
end
