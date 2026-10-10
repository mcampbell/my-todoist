# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

# RAILS_RELATIVE_URL_ROOT=/todo serves the app at {HOST}/todo behind nginx:
# Rack moves the prefix into SCRIPT_NAME, so route helpers add it back.
map ENV.fetch("RAILS_RELATIVE_URL_ROOT", "/") do
  run Rails.application
end
Rails.application.load_server
