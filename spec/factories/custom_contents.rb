FactoryBot.define do
  factory :custom_content do
    sequence(:title) { |i| "MyString#{i}" }
    body { "MyText" }
    published_at { "2019-11-04 12:45:39" }

    factory :project, class: 'Project' do
      type { "Project" }
      body {
        "<p>Based on these responses, what are your next steps?</p>"\
        "<textarea id='test-question-id' data-bz-retained=\"h2c2-0600-next-steps\" placeholder=\"\"></textarea>"
      }
    end

    factory :survey, class: 'Survey' do
      title { 'Test Impact Survey' }
      type { 'Survey' }
      body {
        "<h5>Note: If you were absent from this Learning Lab, please do not "\
        "complete the survey -- it will not count against you.</h5>"\
        "<p>Do you have any feedback on today's Learning Lab? Things that "\
        "could improved, or anything you feel confused about? Feedback about "\
        "your Leadership Coach?</p>"\
        "<p><input name=\"unique_input_name\" type=\"text\"></p>"
      }
    end
  end
end
