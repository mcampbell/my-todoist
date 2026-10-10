require "rails_helper"

# Served behind nginx at {HOST}/todo: config.ru mounts the app under
# RAILS_RELATIVE_URL_ROOT, so Rack moves "/todo" into SCRIPT_NAME. Boots the
# real config.ru, since request specs bypass it.
RSpec.describe "Mounted under a sub-path" do
  around do |example|
    saved = ENV["RAILS_RELATIVE_URL_ROOT"]
    ENV["RAILS_RELATIVE_URL_ROOT"] = "/todo"
    example.run
  ensure
    ENV["RAILS_RELATIVE_URL_ROOT"] = saved
  end

  let(:app) { Rack::Builder.parse_file(Rails.root.join("config.ru").to_s) }

  def get(path) = Rack::MockRequest.new(app).get(path)

  it "redirects to the login form under the prefix" do
    expect(get("/todo/").location).to end_with("/todo/session/new")
  end

  it "renders prefixed form action, icons, and the prefix for JS" do
    body = get("/todo/session/new").body
    expect(body).to include('action="/todo/session"')
    expect(body).to include('href="/todo/icon.png"')
    expect(body).to include('<meta name="script-name" content="/todo">')
  end

  it "does not serve the app outside the prefix" do
    expect(get("/session/new").status).to eq(404)
  end
end
