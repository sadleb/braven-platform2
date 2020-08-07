FactoryBot.define do
  factory :lti_launch do
    client_id { '160040000000055555' }
    login_hint { '914c015dc6637dfb1518ef9c9e02a5918940f67d' }
    target_link_uri { 'https://some/target/link/uri' }
    lti_message_hint { 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ2ZXJpZmllciI6ImQ0OTZjNGMxMGQzMTc5ZGRhNTI4Yjg2MjM3YTY4ZDAyNjEzMDEzYmFkMDUwMGZhZDM5ZDY1N2E0MzZmZDMyMWJjYTBjMWJmYzVmNTY3OWI5ZTQyMDY0NTRhNzQ4ZjAyODM0NmRmNTVhY2VlM2FiOTFjZDA0ZmQwNzU2NGFlZDJkIiwiY2FudmFzX2RvbWFpbiI6ImJyYXZlbi5pbnN0cnVjdHVyZS5jb20iLCJjb250ZXh0X3R5cGUiOiJDb3Vyc2UiLCJjb250ZXh0X2lkIjoxNjAwNTAwMDAwMDAwMDAwNDAsImV4cCI6MTU5MzA4NzYyNX0.mUvaDSdCo-dh-PDCHhL6iDs5Py2hzPU1_bJcKQyWveM' }
   
    factory :lti_launch_login_params, class: Hash do
      skip_create # This isn't stored in the DB.
      iss { Rails.application.secrets.lti_oidc_base_uri }
      canvas_region { "us-west-2" }
      initialize_with { attributes.stringify_keys }
    end

    factory :lti_launch_model do
      nonce { SecureRandom.hex(10) }
      state { SecureRandom.uuid }
  
      factory :lti_launch_canvas do
        transient do
          canvas_user_id { 5555 }
          course_id { 55 }
        end

        factory :lti_launch_assignment do
          transient do
            assignment_id { 555 }
          end
          id_token_payload { JSON.parse FactoryBot.json(:lti_launch_assignment_message, course_id: course_id, canvas_user_id: canvas_user_id, assignment_id: assignment_id) }
        end 

        factory :lti_launch_assignment_selection do
          id_token_payload { JSON.parse FactoryBot.json(:lti_launch_assignment_selection_message, course_id: course_id, canvas_user_id: canvas_user_id) }
        end 
      end
    end
  end
end
