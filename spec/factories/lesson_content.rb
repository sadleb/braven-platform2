FactoryBot.define do
  factory :lesson_content do

    after :build do |lc, evaluator|
      lc.lesson_content_zipfile.attach(io: File.open("#{Rails.root}/spec/fixtures/example_rise360_package.zip"), filename: 'example_rise360_package.zip', content_type: 'application/zip') 
    end
  end
end

# Copy-pasta-ed from course_contents.rb
# FactoryBot.define do
#   factory :course_content do
#     title { "MyString" }
#     body { "MyText" }
#     published_at { "2019-11-04 12:45:39" }
#     content_type { "MyText" }

#     factory :course_content_assignment do
#       content_type { "assignment" }
#     end

#     factory :course_content_module do
#       content_type { "wiki_page" }
#     end
#   end
# end
