FactoryBot.define do
  factory :base_course_custom_content_version do
    # This parent factory's associations intentionally left blank.
    # Pass in base_course and project_version or survey_version
    # to use it directly rather than the nested factories.

    sequence(:canvas_assignment_id)

    factory :course_project_version, class: 'BaseCourseProjectVersion' do
      type { "BaseCourseProjectVersion" }
      association :base_course, factory: :course
      project_version 
      custom_content_version { project_version }
    end

    factory :course_template_project_version, class: 'BaseCourseProjectVersion' do
      type { "BaseCourseProjectVersion" }
      association :base_course, factory: :course_template
      project_version 
      custom_content_version { project_version }
    end

    factory :course_survey_version, class: 'BaseCourseSurveyVersion' do
      type { "BaseCourseSurveyVersion" }
      association :base_course, factory: :course
      survey_version
      custom_content_version { survey_version }
    end

    factory :course_template_survey_version, class: 'BaseCourseSurveyVersion' do
      type { "BaseCourseSurveyVersion" }
      association :base_course, factory: :course_template
      survey_version
      custom_content_version { survey_version }
    end
  end
end
