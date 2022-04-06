FactoryBot.define do
  factory :course do
    sequence(:name) { |i| "Course #{i}" }
    sequence(:canvas_course_id)
    is_launched { false } # Default is less restrictive. Set is_launched = true if you want more restrictive.

    factory :course_launched do
      sequence(:salesforce_program_id) { |i| "003a%011dZXa" % i }
      is_launched { true }
    end

    factory :course_unlaunched do # for convenience
      sequence(:salesforce_program_id) { |i| "003a%011dZXb" % i }
      is_launched { false }
    end

    factory :course_with_resource do
      association :course_resource, factory: :course_resource_with_zipfile
    end
  end
end
