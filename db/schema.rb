# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_15_002246) do
  create_table "completed_occurrences", force: :cascade do |t|
    t.string "task_title", null: false
    t.string "project_name"
    t.integer "priority", null: false
    t.string "label_names"
    t.datetime "due_at"
    t.datetime "completed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "all_day", default: false, null: false
    t.text "notes"
    t.text "completion_notes"
  end

  create_table "labels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false, collation: "NOCASE"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_labels_on_name", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false, collation: "NOCASE"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_projects_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "task_labels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "label_id", null: false
    t.integer "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["label_id"], name: "index_task_labels_on_label_id"
    t.index ["task_id", "label_id"], name: "index_task_labels_on_task_id_and_label_id", unique: true
    t.index ["task_id"], name: "index_task_labels_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "due_at"
    t.text "notes"
    t.integer "priority", default: 0, null: false
    t.integer "project_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.boolean "all_day", default: false, null: false
    t.string "recurrence"
    t.datetime "recurrence_anchor_at"
    t.boolean "recurrence_anchor_all_day"
    t.boolean "in_progress", default: false, null: false
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.check_constraint "priority BETWEEN 0 AND 3", name: "priority_range"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "sessions", "users"
  add_foreign_key "task_labels", "labels"
  add_foreign_key "task_labels", "tasks"
  add_foreign_key "tasks", "projects", on_delete: :nullify
end
