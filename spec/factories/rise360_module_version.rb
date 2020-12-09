FactoryBot.define do
  factory :rise360_module_version do
    name { "MyString" }
    user { build(:admin_user) }

    rise360_module

    after :build do |version, evaluator|
      version.rise360_zipfile.attach(io: File.open("#{Rails.root}/spec/fixtures/example_rise360_package.zip"), filename: 'example_rise360_package.zip', content_type: 'application/zip')
    end
  end
end
