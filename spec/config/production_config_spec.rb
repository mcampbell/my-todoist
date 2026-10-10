require "spec_helper"

# Plain RSpec, no Rails boot: booting the production env in the suite needs
# APP_HOST and a secret key. A text check on the file covers the settings.
RSpec.describe "config/environments/production.rb" do
  let(:config) { File.read(File.expand_path("../../config/environments/production.rb", __dir__)) }

  it "trusts the TLS-terminating proxy (nginx)" do
    expect(config).to match(/^\s*config\.assume_ssl = true$/)
  end

  it "forces HTTPS, HSTS, and secure cookies" do
    expect(config).to match(/^\s*config\.force_ssl = true$/)
  end

  # HSTS on the apex would otherwise force every *.unixgeek.com site to HTTPS
  # for two years.
  it "keeps HSTS off subdomains" do
    expect(config).to match(/^\s*config\.ssl_options = \{ hsts: \{ subdomains: false \} \}$/)
  end

  it "allows only the APP_HOST host header" do
    expect(config).to match(/^\s*config\.hosts = \[ ENV\.fetch\("APP_HOST"\) \]$/)
  end
end
