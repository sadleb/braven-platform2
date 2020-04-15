FactoryBot.define do
  # Represents an enrollment returned from the canvas API
  factory :canvas_enrollment, class: Hash do
    skip_create # This isn't stored in the DB.
    sequence(:id) 
    sequence(:user_id) 
    role { :StudentEnrollment }
    sequence(:course_id)
    sequence(:course_section_id)
    # The rest aren't used in our code. Add them as necessary.

    canvas_user

    factory :canvas_enrollment_student do
      role { :StudentEnrollment }
    end

    factory :canvas_enrollment_ta do
      role { :TaEnrollment }
    end

    initialize_with { attributes.stringify_keys }
  end
end

# Example
#{
#    "associated_user_id": null,
#    "course_id": 69,
#    "course_integration_id": null,
#    "course_section_id": 798,
#    "created_at": "2019-08-07T05:38:33Z",
#    "end_at": null,
#    "enrollment_state": "active",
#    "grades": {
#        "current_grade": null,
#        "current_score": null,
#        "final_grade": null,
#        "final_score": 0.0,
#        "html_url": "https://bebraven.instructure.com/courses/69/grades/1968"
#    },
#    "html_url": "https://bebraven.instructure.com/courses/69/users/1968",
#    "id": 8236,
#    "last_activity_at": "2019-11-07T02:52:14Z",
#    "limit_privileges_to_course_section": true,
#    "role": "StudentEnrollment",
#    "role_id": 4,
#    "root_account_id": 1,
#    "section_integration_id": null,
#    "sis_course_id": null,
#    "sis_import_id": null,
#    "sis_section_id": null,
#    "start_at": null,
#    "total_activity_time": 26713,
#    "type": "StudentEnrollment",
#    "updated_at": "2019-09-16T18:27:59Z",
#    "user": {
#        "email": "testemail@example.com",
#        "id": 1968,
#        "integration_id": null,
#        "login_id": "testemail@example.com",
#        "name": "Example Name",
#        "short_name": "Example",
#        "sis_import_id": null,
#        "sis_login_id": "testemail@example.com",
#        "sis_user_id": "BVID5697-SISID",
#        "sortable_name": "Name, Example"
#    },
#    "user_id": 1968
#}
