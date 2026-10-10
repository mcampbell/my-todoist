# S2 - Production hardening + deploy doc: implementation plan

Parent: design/auth.md (decisions 3, 6). Runs in parallel with S1.
Branch from latest `main`. No dev/test behavior change.

## Steps

1. **Failing spec first** - `spec/config/production_config_spec.rb`:
   load `config/environments/production.rb` text (or boot a
   production-config check) and assert `assume_ssl`, `force_ssl`, and
   `hosts` reads `APP_HOST`. Keep it cheap: a text/regex check on the
   file is enough; booting production env in specs is not worth it.

2. **`config/environments/production.rb`**:
   - Uncomment `config.assume_ssl = true` (nginx terminates TLS).
   - Uncomment `config.force_ssl = true` (HSTS, secure cookies).
   - `config.hosts = [ ENV.fetch("APP_HOST") ]` - fails loud at boot if
     unset. Value on server: `unixgeek.com`.
   - `config.host_authorization = { exclude: ->(request) { request.path == "/up" } }`
     only if a health check route exists (`/up` - check routes; currently
     absent, so skip).

3. **Secret key** - no `config/master.key` in repo (only
   `credentials.yml.enc`). Production needs `secret_key_base` for signed
   session cookies. Use env var `SECRET_KEY_BASE` (`bin/rails secret`) on
   the server - no credentials change. Document in deploy doc.

4. **`design/deploy-nginx.md`** - deploy runbook:
   - Env: `RAILS_ENV=production`, `APP_HOST=unixgeek.com`,
     `SECRET_KEY_BASE=...`, `RAILS_LOG_LEVEL=info`.
   - OS packages: Ruby 3.4, nginx, certbot, `sqlite3` CLI (backup script
     shells out to it).
   - First run: `bundle config set without "development test"`,
     `bundle install` (Bundler 4 removed `--without`),
     `bin/rails db:prepare`, `bin/rails assets:precompile`,
     `bin/rails user:create EMAIL=... PASSWORD=...` (needs S1).
   - Puma bound to `127.0.0.1:3000` only (never public). `config/puma.rb`
     `port` binds all interfaces, so the systemd unit binds explicitly.
   - systemd unit for Puma: `ExecStart=bin/rails server -b 127.0.0.1 -p 3000`,
     `Restart=on-failure`. Firewall (step below) is the second layer.
   - nginx server block:
     - `server_name unixgeek.com;` TLS via certbot (Let's Encrypt).
     - port 80 -> 301 to https.
     - default server returns 444 for unknown hosts.
     - `proxy_set_header Host $host; X-Forwarded-Proto $scheme;
       X-Forwarded-For $proxy_add_x_forwarded_for;`
     - `limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;` -
       `http` context only: put it at the top of the site file, outside
       `server {}` (sites-enabled files load inside `http`).
       `location = /session { limit_req zone=login burst=5 nodelay; proxy_pass ...; }`
       (applies to all methods on `/session`; GET of login form is
       `/session/new`, so unaffected).
   - Backups: cron `RAILS_ENV=production bin/create-backup.sh` daily
     (script defaults to the development DB); note backups dir is on
     same disk - copy off-host if wanted.
   - Firewall: allow 22, 80, 443 only.

5. **Verify** - `bin/rspec`, `bin/rubocop`.
   Manual (optional, local): `APP_HOST=localhost SECRET_KEY_BASE=$(bin/rails secret)
   RAILS_ENV=production bin/rails s` boots; request with other Host -> 403.

## Files touched
config/environments/production.rb, design/deploy-nginx.md, one spec.

## Done when
Production config forces HTTPS behind proxy and allows only APP_HOST;
deploy doc lets a fresh server reach a working login page.

## Unresolved
- Server OS / process manager - assumed Linux + systemd. Confirm.
- Off-host backup target - none chosen.
