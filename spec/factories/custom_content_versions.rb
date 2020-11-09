FactoryBot.define do
  factory :custom_content_version do
    title { "MyString" }
    body { "MyText" }

    user { build(:admin_user) }
    custom_content

    factory :project_version, class: 'ProjectVersion' do
      type { "ProjectVersion" }
      body {
        "<p>Based on these responses, what are your next steps?</p>"\
        "<textarea id='test-question-id' data-bz-retained=\"h2c2-0600-next-steps\" placeholder=\"\"></textarea>"\
        "<select id='test-selector-id' data-bz-retained=\"h2c2-0600-next-steps\"><option value='A'>A</option></select>"
      }
      custom_content { build(:project) }
    end

    factory :survey_version, class: 'SurveyVersion' do
      type { 'SurveyVersion' }
      title { 'Impact Survey' }
      body {
        "<h5>Note: If you were absent from this Learning Lab, please do not "\
        "complete the survey -- it will not count against you.</h5>"\
        "<p>Do you have any feedback on today's Learning Lab? Things that "\
        "could improved, or anything you feel confused about? Feedback about "\
        "your Leadership Coach?</p>"\
        "<p><input name=\"unique_input_name\" type=\"text\"></p>"
      }
      custom_content { build(:survey) }
    end
  end
end
