FactoryBot.define do
  factory :accelerator_survey_submission do
    # This parent factory's associations intentionally left blank.
    # Pass in course and user to use this.
    association :course, factory: :course
    association :user, factory: :user
  end
end
