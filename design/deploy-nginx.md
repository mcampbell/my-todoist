# Deploy behind nginx

Single server, Linux + systemd. nginx terminates TLS for `unixgeek.com` and
proxies to Puma on loopback. Parent design: design/auth.md.

This doc serves the app at the domain root under systemd. For a sub-path
(`{HOST}/todo`) under tmux, follow README "Deployment" instead.

Commands assume app checkout at `/srv/my-todoist`, owned by user `todoist`.
Change paths to suit.

## 1. Packages

Ruby 3.4 (same as `.ruby-version`), nginx, certbot (nginx plugin), and the
`sqlite3` CLI - `bin/create-backup.sh` shells out to it.

```sh
sudo apt install nginx certbot python3-certbot-nginx sqlite3 build-essential libyaml-dev
```

## 2. Environment file

`/etc/my-todoist.env` (mode 600, owner `todoist`):

```sh
RAILS_ENV=production
APP_HOST=unixgeek.com
SECRET_KEY_BASE=<output of: bin/rails secret>
RAILS_LOG_LEVEL=info
```

- `SECRET_KEY_BASE` signs the login cookie. The repo has no
  `config/master.key`, so `RAILS_MASTER_KEY` does not apply.
- The app refuses to boot without `APP_HOST` (`KeyError`), for every
  command: server, `db:prepare`, `assets:precompile`, rake tasks. Load the
  file first: `set -a; . /etc/my-todoist.env; set +a`.

## 3. First run

```sh
cd /srv/my-todoist
set -a; . /etc/my-todoist.env; set +a
bundle config set without "development test"   # Bundler 4 removed --without
bundle install
bin/rails db:prepare
bin/rails assets:precompile
 bin/rails user:create EMAIL=you@example.com PASSWORD='12+ chars'
```

The leading space on the last line keeps the password out of shell history
when `HISTCONTROL=ignorespace` (bash default on Debian/Ubuntu). Password
minimum: 12 characters. To change it later (also ends every login):
` bin/rails user:modify EMAIL=you@example.com PASSWORD='...'`.

## 4. Puma under systemd

`/etc/systemd/system/my-todoist.service`:

```ini
[Unit]
Description=my-todoist
After=network.target

[Service]
User=todoist
WorkingDirectory=/srv/my-todoist
EnvironmentFile=/etc/my-todoist.env
# -b binds loopback only. config/puma.rb `port` alone binds every interface.
ExecStart=/srv/my-todoist/bin/rails server -b 127.0.0.1 -p 3000
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```sh
sudo systemctl daemon-reload && sudo systemctl enable --now my-todoist
```

## 5. nginx

`/etc/nginx/sites-available/my-todoist` (symlink into `sites-enabled`):

```nginx
# http context only - nginx refuses to start if this is inside server {}.
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

# Drop any request whose Host is not ours (scanners hitting the bare IP).
# ssl_reject_handshake needs nginx >= 1.19.4 (`nginx -v`).
server {
    listen 80 default_server;
    listen 443 ssl default_server;
    ssl_reject_handshake on;
    return 444;
}

server {
    listen 80;
    server_name unixgeek.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name unixgeek.com;
    # ssl_certificate lines: added by certbot (step 6).

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    # Login POST only; the form itself is /session/new.
    location = /session {
        limit_req zone=login burst=5 nodelay;
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

- The port 80 -> HTTPS redirect must live here. Rails runs with
  `assume_ssl`, so it treats every request as HTTPS and never redirects
  plain HTTP itself.
- `X-Forwarded-For` gives Rails the client IP for its own login limit
  (10 tries / 3 min). nginx on loopback is a trusted proxy by default.
- Rails sends HSTS for `unixgeek.com` only, not its subdomains.

## 6. TLS certificate

```sh
sudo certbot --nginx -d unixgeek.com
sudo nginx -t && sudo systemctl reload nginx
```

certbot installs a renewal timer.

## 7. Firewall

```sh
sudo ufw allow 22 && sudo ufw allow 80 && sudo ufw allow 443 && sudo ufw enable
```

Puma's loopback bind (step 4) is the first layer; this is the second.

## 8. Backups

crontab for `todoist`:

```cron
15 3 * * * cd /srv/my-todoist && RAILS_ENV=production bin/create-backup.sh
```

`RAILS_ENV=production` is required: the script defaults to the development
database and exits 1 when it is missing. Backups land in `backups/` on the
same disk (last 5 kept). Copy them off the host if a disk loss matters.

## 9. Check

```sh
curl -sI https://unixgeek.com/ | head -1                     # 302 to /session/new
curl -sI http://unixgeek.com/ | head -1                      # 301 to https
curl -sI -H 'Host: evil.example' https://unixgeek.com/ -k   # dropped / 403
```

## Updates

```sh
cd /srv/my-todoist && git pull
set -a; . /etc/my-todoist.env; set +a
bundle install && bin/rails db:migrate && bin/rails assets:precompile
sudo systemctl restart my-todoist
```
