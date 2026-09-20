#!/usr/bin/env bash
set -euo pipefail

# Safe SQLite backup: uses sqlite3's online ".backup" (the SQLite Backup
# API), not a file copy. A plain `cp` of the .sqlite3 file can miss data
# still sitting in the -wal file, or copy mid-write and land a corrupt
# backup -- .backup reads through SQLite itself, so it's consistent even
# while the app has the database open in WAL mode.
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env="${RAILS_ENV:-development}"
db_path="$root_dir/storage/${env}.sqlite3"
backups_dir="$root_dir/backups"
backup_path="$backups_dir/${env}-$(date +%Y%m%d%H%M%S).sqlite3"
tmp_path="$backup_path.tmp"

if [[ ! -f "$db_path" ]]; then
  echo "create-backup: no database at $db_path" >&2
  exit 1
fi

mkdir -p "$backups_dir"
trap 'rm -f "$tmp_path"' EXIT

# Back up to a temp name, then rename into place -- if the backup is
# interrupted partway, the final .sqlite3 name never points at a partial file.
sqlite3 "$db_path" ".backup '$tmp_path'"
mv "$tmp_path" "$backup_path"

# Keep only the 5 most recent backups in the directory (across all envs).
ls -t "$backups_dir"/*.sqlite3 | tail -n +6 | xargs -r rm -f

echo "Backed up $db_path -> $backup_path"
