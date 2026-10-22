require "spec_helper"

# Plain RSpec, no Rails boot: puma.rb is evaluated by the Puma DSL at server
# start. A text check on the file covers the binding.
RSpec.describe "config/puma.rb" do
  let(:config) { File.read(File.expand_path("../../config/puma.rb", __dir__)) }

  # Puma runs behind nginx on the same host; binding every interface would
  # expose plaintext HTTP beside nginx's TLS (security audit NV-1).
  it "binds to loopback only" do
    expect(config).to match(/^\s*bind "tcp:\/\/127\.0\.0\.1:#\{ENV\.fetch\("PORT", 3000\)\}"$/)
  end

  # An interface-wide bind can only come from the `port` DSL (it expands to
  # tcp://0.0.0.0 at runtime, which never appears literally in the file), so
  # ban the directive, not any exact line form.
  it "does not bind every interface" do
    expect(config).not_to match(/^\s*port\b/)
  end
end
