require "spec_helper"
require "open3"
require "fileutils"

# Plain RSpec, no Rails environment: this exercises bin/create-backup.sh as an
# external process, not app code. It backs up storage/test.sqlite3, which
# already exists by the time the suite runs -- RSpec's own Rails boot creates
# it before any spec file loads.
RSpec.describe "bin/create-backup.sh" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:script) { File.join(root, "bin", "create-backup.sh") }
  let(:backups_dir) { File.join(root, "backups") }

  around do |example|
    existed = File.directory?(backups_dir)
    before = existed ? Dir.children(backups_dir) : []
    example.run
    (Dir.children(backups_dir) - before).each { |f| File.delete(File.join(backups_dir, f)) } if File.directory?(backups_dir)
    FileUtils.rmdir(backups_dir) if !existed && File.directory?(backups_dir) && Dir.empty?(backups_dir)
  end

  def run_script(env)
    Open3.capture3({ "RAILS_ENV" => env }, script)
  end

  it "backs up the target environment's database into backups/, creating the directory" do
    FileUtils.rm_rf(backups_dir)

    _stdout, stderr, status = run_script("test")

    expect(status).to be_success, stderr
    expect(File.directory?(backups_dir)).to eq(true)
    backup_files = Dir.glob(File.join(backups_dir, "test-*.sqlite3"))
    expect(backup_files.size).to eq(1)
  end

  it "produces a valid, queryable SQLite database with the source's tables" do
    run_script("test")
    backup_file = Dir.glob(File.join(backups_dir, "test-*.sqlite3")).max_by { |f| File.mtime(f) }

    source_tables, = Open3.capture2("sqlite3", File.join(root, "storage", "test.sqlite3"), ".tables")
    backup_tables, = Open3.capture2("sqlite3", backup_file, ".tables")

    expect(backup_tables).to eq(source_tables)
  end

  it "does not copy the -wal/-shm files -- only the single backup file appears" do
    run_script("test")

    expect(Dir.glob(File.join(backups_dir, "*"))).to all(match(/\.sqlite3\z/))
  end

  it "exits non-zero and writes nothing when the target database does not exist" do
    _stdout, _stderr, status = run_script("no_such_env")

    expect(status).not_to be_success
    expect(Dir.glob(File.join(backups_dir, "no_such_env-*"))).to be_empty
  end
end
