FactoryBot.define do
  factory :lesson_content do

    after :build do |lc, evaluator|
      lc.lesson_content_zipfile.attach(io: File.open("#{Rails.root}/spec/fixtures/example_rise360_package.zip"), filename: 'example_rise360_package.zip', content_type: 'application/zip') 
    end
  end
end
