json.extract! course_content_answer, :id, :uuid, :course_content_id, :correctness, :mastery, :instant_feedback, :created_at, :updated_at
json.url course_content_answer_url(course_content_answer, format: :json)
