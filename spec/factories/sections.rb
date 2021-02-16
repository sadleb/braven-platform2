FactoryBot.define do
  factory :section do
    sequence(:name) { |i| "Section Name #{i}" }
    association :course

    factory :ta_section do
      name { SectionConstants::TA_SECTION }
      association :course
    end
  end
end
