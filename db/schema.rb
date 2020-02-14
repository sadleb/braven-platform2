# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_02_11_154757) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "access_tokens", force: :cascade do |t|
    t.string "name"
    t.string "key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_access_tokens_on_key", unique: true
    t.index ["name"], name: "index_access_tokens_on_name", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "line1", null: false
    t.string "line2"
    t.string "city", null: false
    t.string "state", null: false
    t.string "zip", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "course_contents", force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.datetime "published_at"
    t.string "content_type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "course_id"
    t.string "secondary_id"
    t.string "course_name"
  end

  create_table "emails", force: :cascade do |t|
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["value"], name: "index_emails_on_value"
  end

  create_table "industries", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_industries_on_name"
  end

  create_table "interests", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_interests_on_name"
  end

  create_table "location_relationships", id: false, force: :cascade do |t|
    t.integer "parent_id"
    t.integer "child_id"
    t.index ["child_id"], name: "index_location_relationships_on_child_id"
    t.index ["parent_id", "child_id"], name: "index_location_relationships_on_parent_id_and_child_id"
    t.index ["parent_id"], name: "index_location_relationships_on_parent_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_locations_on_code", unique: true
    t.index ["name"], name: "index_locations_on_name", unique: true
  end

  create_table "login_tickets", force: :cascade do |t|
    t.string "ticket", null: false
    t.datetime "created_on", null: false
    t.datetime "created_at", null: false
    t.datetime "consumed"
    t.string "client_hostname", null: false
  end

  create_table "majors", force: :cascade do |t|
    t.string "name"
    t.integer "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_majors_on_name"
    t.index ["parent_id"], name: "index_majors_on_parent_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_organizations_on_name", unique: true
  end

  create_table "phones", force: :cascade do |t|
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["value"], name: "index_phones_on_value", unique: true
  end

  create_table "postal_codes", force: :cascade do |t|
    t.string "code"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "msa_code"
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "city"
    t.index ["code"], name: "index_postal_codes_on_code", unique: true
    t.index ["state"], name: "index_postal_codes_on_state"
  end

  create_table "program_memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "program_id", null: false
    t.integer "role_id", null: false
    t.date "start_date"
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["program_id"], name: "index_program_memberships_on_program_id"
    t.index ["role_id"], name: "index_program_memberships_on_role_id"
    t.index ["user_id", "program_id", "role_id"], name: "program_memberships_index"
    t.index ["user_id"], name: "index_program_memberships_on_user_id"
  end

  create_table "programs", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "term", null: false
    t.integer "organization_id", null: false
    t.string "type"
    t.index ["name", "term", "organization_id"], name: "index_programs_on_name_and_term_and_organization_id", unique: true
    t.index ["name"], name: "index_programs_on_name", unique: true
  end

  create_table "proxy_granting_tickets", force: :cascade do |t|
    t.string "ticket", null: false
    t.datetime "created_on", null: false
    t.datetime "created_at", null: false
    t.string "client_hostname", null: false
    t.string "iou", null: false
    t.bigint "service_ticket_id"
    t.index ["service_ticket_id"], name: "index_proxy_granting_tickets_on_service_ticket_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "service_tickets", force: :cascade do |t|
    t.string "ticket", null: false
    t.string "service", null: false
    t.datetime "created_on", null: false
    t.datetime "created_at", null: false
    t.datetime "consumed"
    t.string "client_hostname", null: false
    t.string "username", null: false
    t.integer "proxy_granting_ticket_id"
    t.integer "ticket_granting_ticket_id"
  end

  create_table "ticket_granting_tickets", force: :cascade do |t|
    t.string "ticket", null: false
    t.datetime "created_on", null: false
    t.datetime "created_at", null: false
    t.string "client_hostname", null: false
    t.string "username", null: false
    t.string "remember_me", null: false
    t.string "extra_attributes", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.string "first_name", default: "", null: false
    t.string "middle_name"
    t.string "last_name", default: "", null: false
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["email"], name: "index_users_on_email"
  end

  add_foreign_key "programs", "organizations"
end
