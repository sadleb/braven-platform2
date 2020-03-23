FactoryBot.define do
  factory :course_content_history do
    title { "MyString" }
    body { "MyText" }

    user
    course_content
  end
end
