FactoryBot.define do
  factory :rise360_module do

    factory :rise360_module_with_zipfile do
      after :build do |rm, evaluator|
        rm.lesson_content_zipfile.attach(io: File.open("#{Rails.root}/spec/fixtures/example_rise360_package.zip"), filename: 'example_rise360_package.zip', content_type: 'application/zip') 
      end
    end
  end
end
