FactoryBot.define do
  factory :course_content_answer do
    uuid { "MyString" }
    course_content_id { "" }
    correctness { false }
    mastery { false }
    instant_feedback { false }
  end
end
