FactoryBot.define do
  factory :course_content_undo do
    course_content { nil }
    operation { "MyText" }
    version { "" }
  end
end
