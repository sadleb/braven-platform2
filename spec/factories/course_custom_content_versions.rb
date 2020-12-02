FactoryBot.define do
  factory :course_custom_content_version do
    # This parent factory's associations intentionally left blank.
    # Pass in course and project_version or survey_version
    # to use it directly rather than the nested factories.

    sequence(:canvas_assignment_id)

    factory :course_project_version, class: 'CourseProjectVersion' do
      type { "CourseProjectVersion" }
      association :course, factory: :course
      project_version 
      custom_content_version { project_version }
    end

    factory :course_survey_version, class: 'CourseSurveyVersion' do
      type { "CourseSurveyVersion" }
      association :course, factory: :course
      survey_version
      custom_content_version { survey_version }
    end

  end
end
