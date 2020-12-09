FactoryBot.define do
  factory :rise360_module do
    name { 'Module: Test Rise360 Module' }
    factory :rise360_module_with_zipfile do
      after :build do |rm, evaluator|
        rm.rise360_zipfile.attach(io: File.open("#{Rails.root}/spec/fixtures/example_rise360_package.zip"), filename: 'example_rise360_package.zip', content_type: 'application/zip')
      end
    end
  end
end
