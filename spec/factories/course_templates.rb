FactoryBot.define do
  factory :course_template do
    sequence(:name) { |i| "CourseTemplate #{i}" }
    type { "CourseTemplate" }

    factory :course_template_with_canvas_id do
      # TODO: make this a sequence. The hard-coded value can conflict with the course factory.
      # Do the same with the course factory. Need to have the sequences not overlap though...?
      # Also, rename course_id to canvas_course_id in lti_launch factory:
      # https://app.asana.com/0/1174274412967132/1199242921759773
      canvas_course_id { 77 }

      factory :course_template_with_resource do
        association :course_resource, factory: :course_resource_with_zipfile
      end
    end
  end
end
