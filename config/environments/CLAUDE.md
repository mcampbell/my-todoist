# config/environments

## Purpose
Per-environment Rails settings.

## Files
- development.rb - reloading on, eager_load off, memory cache store, caching toggled by tmp/caching-dev.txt.
- production.rb - eager_load on, assume_ssl and force_ssl on, logs to STDOUT, HSTS without subdomains.
- test.rb - eager_load only when CI is set, forgery protection off, memory cache store.

## Rules for agents
- production.rb sets config.hosts to ENV.fetch("APP_HOST"). Boot fails without APP_HOST. Do not remove it.
- Keep force_ssl and assume_ssl on. TLS ends at nginx.
- Production log level comes from RAILS_LOG_LEVEL (default info).
- Put shared settings in config/application.rb, not in all three files.

## Verification
- `bin/rspec` (uses test.rb)
- `bin/rubocop`
- `APP_HOST=example.com RAILS_ENV=production bin/rails runner 'puts 1'` checks production boot (needs credentials key).
