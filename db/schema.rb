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

ActiveRecord::Schema.define(version: 2021_03_09_151146) do

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

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "attendance_event_submission_answers", force: :cascade do |t|
    t.bigint "attendance_event_submission_id", null: false
    t.bigint "for_user_id", null: false
    t.boolean "in_attendance"
    t.boolean "late"
    t.string "absence_reason"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["attendance_event_submission_id"], name: "index_attendance_event_submission_answers_on_submission_id"
    t.index ["for_user_id"], name: "index_attendance_event_submission_answers_on_for_user_id"
  end

  create_table "attendance_event_submissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "course_attendance_event_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_attendance_event_id"], name: "index_submissions_on_course_attendance_event_id"
    t.index ["user_id"], name: "index_attendance_event_submissions_on_user_id"
  end

  create_table "attendance_events", force: :cascade do |t|
    t.string "title", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "event_type"
  end

  create_table "course_attendance_events", force: :cascade do |t|
    t.bigint "attendance_event_id", null: false
    t.bigint "course_id", null: false
    t.bigint "canvas_assignment_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["attendance_event_id"], name: "index_course_attendance_events_on_attendance_event_id"
    t.index ["course_id"], name: "index_course_attendance_events_on_course_id"
  end

  create_table "course_custom_content_versions", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "custom_content_version_id", null: false
    t.bigint "canvas_assignment_id", null: false
    t.string "type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_id", "custom_content_version_id"], name: "index_course_custom_content_version_unique_version_ids", unique: true
    t.index ["course_id"], name: "index_course_custom_content_versions_on_course_id"
    t.index ["custom_content_version_id"], name: "index_course_custom_content_versions_on_version_id"
  end

  create_table "course_resources", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "course_rise360_module_versions", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "rise360_module_version_id", null: false
    t.bigint "canvas_assignment_id"
    t.index ["canvas_assignment_id"], name: "index_course_rise360_module_versions_on_canvas_assignment_id", unique: true
    t.index ["course_id"], name: "index_course_rise360_module_versions_on_course_id"
    t.index ["rise360_module_version_id"], name: "index_course_module_versions_on_module_version_id "
  end

  create_table "courses", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "canvas_course_id"
    t.bigint "course_resource_id"
    t.boolean "is_launched", default: false
    t.index ["course_resource_id"], name: "index_courses_on_course_resource_id"
    t.index ["name"], name: "index_courses_on_name", unique: true
  end

  create_table "custom_content_versions", force: :cascade do |t|
    t.bigint "custom_content_id", null: false
    t.string "title"
    t.text "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id"
    t.string "type"
    t.index ["custom_content_id"], name: "index_custom_content_versions_on_custom_content_id"
    t.index ["user_id"], name: "index_custom_content_versions_on_user_id"
  end

  create_table "custom_contents", force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.datetime "published_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "type"
  end

  create_table "fellow_evaluation_submission_answers", force: :cascade do |t|
    t.bigint "fellow_evaluation_submission_id", null: false
    t.bigint "for_user_id", null: false
    t.string "input_name"
    t.string "input_value"
    t.index ["fellow_evaluation_submission_id"], name: "index_fellow_evaluation_submission_answers_on_submission_id"
    t.index ["for_user_id"], name: "index_fellow_evaluation_submission_answers_on_for_user_id"
  end

  create_table "fellow_evaluation_submissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "course_id", null: false
    t.index ["course_id"], name: "index_fellow_evaluation_submissions_on_course_id"
    t.index ["user_id"], name: "index_fellow_evaluation_submissions_on_user_id"
  end

  create_table "grade_categories", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.string "name", null: false
    t.float "percent_of_grade"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_id"], name: "index_grade_categories_on_course_id"
  end

  create_table "keypairs", force: :cascade do |t|
    t.string "jwk_kid", null: false
    t.string "encrypted__keypair", null: false
    t.string "encrypted__keypair_iv", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at"], name: "index_keypairs_on_created_at"
    t.index ["jwk_kid"], name: "index_keypairs_on_jwk_kid"
  end

  create_table "lesson_submissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "lesson_id", null: false
    t.float "points_received"
    t.datetime "submitted_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["lesson_id"], name: "index_lesson_submissions_on_lesson_id"
    t.index ["user_id"], name: "index_lesson_submissions_on_user_id"
  end

  create_table "lessons", force: :cascade do |t|
    t.bigint "grade_category_id", null: false
    t.string "name", null: false
    t.integer "points_possible", null: false
    t.float "percent_of_grade_category", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["grade_category_id"], name: "index_lessons_on_grade_category_id"
  end

  create_table "location_relationships", id: false, force: :cascade do |t|
    t.integer "parent_id"
    t.integer "child_id"
    t.index ["child_id"], name: "index_location_relationships_on_child_id"
    t.index ["parent_id", "child_id"], name: "index_location_relationships_on_parent_id_and_child_id"
    t.index ["parent_id"], name: "index_location_relationships_on_parent_id"
  end

  create_table "login_tickets", force: :cascade do |t|
    t.string "ticket", null: false
    t.datetime "created_on", null: false
    t.datetime "created_at", null: false
    t.datetime "consumed"
    t.string "client_hostname", null: false
  end

  create_table "lti_launches", force: :cascade do |t|
    t.string "client_id", null: false
    t.string "login_hint", null: false
    t.text "lti_message_hint"
    t.string "target_link_uri", null: false
    t.string "nonce"
    t.string "state", null: false
    t.text "id_token_payload"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "sessionless", default: false
    t.index ["state"], name: "index_lti_launches_on_state", unique: true
  end

  create_table "peer_review_questions", force: :cascade do |t|
    t.string "text", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "peer_review_submission_answers", force: :cascade do |t|
    t.bigint "peer_review_submission_id", null: false
    t.bigint "for_user_id", null: false
    t.string "input_value"
    t.bigint "peer_review_question_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["for_user_id"], name: "index_peer_review_submission_answers_on_for_user_id"
    t.index ["peer_review_question_id"], name: "index_peer_review_submission_answers_on_peer_review_question_id"
    t.index ["peer_review_submission_id"], name: "index_peer_review_submission_answers_on_submission_id"
  end

  create_table "peer_review_submissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "course_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_id"], name: "index_peer_review_submissions_on_course_id"
    t.index ["user_id"], name: "index_peer_review_submissions_on_user_id"
  end

  create_table "project_submission_answers", force: :cascade do |t|
    t.bigint "project_submission_id", null: false
    t.string "input_name"
    t.text "input_value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["project_submission_id", "input_name"], name: "index_project_submission_answers_unique_1", unique: true
    t.index ["project_submission_id"], name: "index_project_submission_answers_on_project_submission_id"
  end

  create_table "project_submissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "course_custom_content_version_id", null: false
    t.boolean "is_submitted"
    t.integer "uniqueness_condition", default: 1
    t.index ["course_custom_content_version_id"], name: "index_project_submissions_on_course_project_version_id"
    t.index ["user_id", "course_custom_content_version_id", "is_submitted", "uniqueness_condition"], name: "index_project_submissions_unique_1", unique: true
    t.index ["user_id"], name: "index_project_submissions_on_user_id"
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

  create_table "rate_this_module_submission_answers", force: :cascade do |t|
    t.string "input_name", null: false
    t.string "input_value"
    t.bigint "rate_this_module_submission_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rate_this_module_submission_id", "input_name"], name: "index_rate_this_module_submission_answers_u1", unique: true
    t.index ["rate_this_module_submission_id"], name: "index_rate_this_module_submission_answers_fkey_1"
  end

  create_table "rate_this_module_submissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "course_rise360_module_version_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_rise360_module_version_id"], name: "index_rate_this_module_submissions_fkey_2"
    t.index ["user_id", "course_rise360_module_version_id"], name: "index_rate_this_module_submissions_unique_1", unique: true
    t.index ["user_id"], name: "index_rate_this_module_submissions_on_user_id"
  end

  create_table "rise360_module_grades", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "course_rise360_module_version_id", null: false
    t.string "canvas_results_url"
    t.index ["course_rise360_module_version_id"], name: "index_rise360_module_grades_on_course_rise360_module_version_id"
    t.index ["user_id", "course_rise360_module_version_id"], name: "index_rise360_module_grades_uniqueness", unique: true
    t.index ["user_id"], name: "index_rise360_module_grades_on_user_id"
  end

  create_table "rise360_module_interactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "activity_id", null: false
    t.boolean "success"
    t.integer "progress"
    t.string "verb", null: false
    t.bigint "canvas_course_id", null: false
    t.bigint "canvas_assignment_id", null: false
    t.boolean "new", default: true, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["canvas_assignment_id", "user_id", "verb"], name: "index_rise360_module_interactions_on_assignment_user_verb"
    t.index ["canvas_assignment_id"], name: "index_rise360_module_interactions_on_canvas_assignment_id"
    t.index ["canvas_course_id", "canvas_assignment_id"], name: "index_rise360_module_interactions_on_course_assignment"
    t.index ["new", "canvas_course_id", "canvas_assignment_id", "user_id"], name: "index_rise360_module_interactions_on_new_course_assignment_user"
    t.index ["user_id"], name: "index_rise360_module_interactions_on_user_id"
  end

  create_table "rise360_module_states", force: :cascade do |t|
    t.bigint "canvas_course_id", null: false
    t.bigint "canvas_assignment_id", null: false
    t.string "activity_id", null: false
    t.bigint "user_id", null: false
    t.string "state_id", null: false
    t.text "value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["canvas_course_id", "canvas_assignment_id", "activity_id", "user_id", "state_id"], name: "module_states_unique_index_1", unique: true
    t.index ["user_id"], name: "index_rise360_module_states_on_user_id"
  end

  create_table "rise360_module_versions", force: :cascade do |t|
    t.bigint "rise360_module_id", null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "activity_id"
    t.integer "quiz_questions"
    t.index ["activity_id"], name: "index_rise360_module_versions_on_activity_id"
    t.index ["rise360_module_id"], name: "index_rise360_module_versions_on_rise360_module_id"
    t.index ["user_id"], name: "index_rise360_module_versions_on_user_id"
  end

  create_table "rise360_modules", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "activity_id"
    t.integer "quiz_questions"
    t.string "name", default: "", null: false
    t.index ["activity_id"], name: "index_rise360_modules_on_activity_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.string "resource_type"
    t.bigint "resource_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource_type_and_resource_id"
  end

  create_table "rubric_grades", force: :cascade do |t|
    t.bigint "project_submission_id", null: false
    t.bigint "rubric_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["project_submission_id"], name: "index_rubric_grades_on_project_submission_id", unique: true
    t.index ["rubric_id"], name: "index_rubric_grades_on_rubric_id"
  end

  create_table "rubric_row_categories", force: :cascade do |t|
    t.bigint "rubric_id", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rubric_id"], name: "index_rubric_row_categories_on_rubric_id"
  end

  create_table "rubric_row_grades", force: :cascade do |t|
    t.bigint "rubric_grade_id", null: false
    t.bigint "rubric_row_id", null: false
    t.integer "points_given"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rubric_grade_id"], name: "index_rubric_row_grades_on_rubric_grade_id"
    t.index ["rubric_row_id"], name: "index_rubric_row_grades_on_rubric_row_id"
  end

  create_table "rubric_row_ratings", force: :cascade do |t|
    t.bigint "rubric_row_id", null: false
    t.string "description", null: false
    t.integer "points_value", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rubric_row_id"], name: "index_rubric_row_ratings_on_rubric_row_id"
  end

  create_table "rubric_rows", force: :cascade do |t|
    t.bigint "rubric_row_category_id", null: false
    t.string "criterion", null: false
    t.integer "points_possible", null: false
    t.integer "position", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rubric_row_category_id"], name: "index_rubric_rows_on_rubric_row_category_id"
  end

  create_table "rubrics", force: :cascade do |t|
    t.string "name"
    t.integer "points_possible", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "sections", force: :cascade do |t|
    t.string "name", null: false
    t.integer "course_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "canvas_section_id"
    t.index ["name", "course_id"], name: "index_sections_on_name_and_course_id", unique: true
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

  create_table "survey_submission_answers", force: :cascade do |t|
    t.bigint "survey_submission_id", null: false
    t.string "input_name", null: false
    t.string "input_value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["survey_submission_id"], name: "index_survey_submission_answers_on_survey_submission_id"
  end

  create_table "survey_submissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "course_custom_content_version_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_custom_content_version_id"], name: "index_survey_submissions_on_course_survey_version_id"
    t.index ["user_id"], name: "index_survey_submissions_on_user_id"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.string "first_name", default: "", null: false
    t.string "middle_name"
    t.string "last_name", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "salesforce_id"
    t.bigint "canvas_user_id"
    t.integer "join_user_id"
    t.string "linked_in_access_token"
    t.string "linked_in_state"
    t.index ["canvas_user_id"], name: "index_users_on_canvas_user_id", unique: true
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "role_id"
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attendance_event_submission_answers", "attendance_event_submissions"
  add_foreign_key "attendance_event_submission_answers", "users", column: "for_user_id"
  add_foreign_key "attendance_event_submissions", "course_attendance_events"
  add_foreign_key "attendance_event_submissions", "users"
  add_foreign_key "course_attendance_events", "attendance_events"
  add_foreign_key "course_attendance_events", "courses"
  add_foreign_key "course_custom_content_versions", "courses"
  add_foreign_key "course_custom_content_versions", "custom_content_versions"
  add_foreign_key "course_rise360_module_versions", "courses"
  add_foreign_key "course_rise360_module_versions", "rise360_module_versions"
  add_foreign_key "courses", "course_resources"
  add_foreign_key "custom_content_versions", "custom_contents"
  add_foreign_key "custom_content_versions", "users"
  add_foreign_key "fellow_evaluation_submission_answers", "fellow_evaluation_submissions"
  add_foreign_key "fellow_evaluation_submission_answers", "users", column: "for_user_id"
  add_foreign_key "fellow_evaluation_submissions", "courses"
  add_foreign_key "fellow_evaluation_submissions", "users"
  add_foreign_key "grade_categories", "courses"
  add_foreign_key "lesson_submissions", "lessons"
  add_foreign_key "lesson_submissions", "users"
  add_foreign_key "lessons", "grade_categories"
  add_foreign_key "peer_review_submission_answers", "peer_review_questions"
  add_foreign_key "peer_review_submission_answers", "peer_review_submissions"
  add_foreign_key "peer_review_submission_answers", "users", column: "for_user_id"
  add_foreign_key "peer_review_submissions", "courses"
  add_foreign_key "peer_review_submissions", "users"
  add_foreign_key "project_submission_answers", "project_submissions"
  add_foreign_key "project_submissions", "course_custom_content_versions"
  add_foreign_key "project_submissions", "users"
  add_foreign_key "rate_this_module_submission_answers", "rate_this_module_submissions"
  add_foreign_key "rate_this_module_submissions", "course_rise360_module_versions"
  add_foreign_key "rate_this_module_submissions", "users"
  add_foreign_key "rise360_module_grades", "course_rise360_module_versions"
  add_foreign_key "rise360_module_grades", "users"
  add_foreign_key "rise360_module_interactions", "users"
  add_foreign_key "rise360_module_states", "users"
  add_foreign_key "rise360_module_versions", "rise360_modules"
  add_foreign_key "rise360_module_versions", "users"
  add_foreign_key "rubric_grades", "project_submissions"
  add_foreign_key "rubric_grades", "rubrics"
  add_foreign_key "rubric_row_categories", "rubrics"
  add_foreign_key "rubric_row_grades", "rubric_grades"
  add_foreign_key "rubric_row_grades", "rubric_rows"
  add_foreign_key "rubric_row_ratings", "rubric_rows"
  add_foreign_key "rubric_rows", "rubric_row_categories"
  add_foreign_key "sections", "courses"
  add_foreign_key "survey_submission_answers", "survey_submissions"
  add_foreign_key "survey_submissions", "course_custom_content_versions"
  add_foreign_key "survey_submissions", "users"
end
