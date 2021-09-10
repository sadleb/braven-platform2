FactoryBot.define do
  factory :rise360_module_grade do
    association :user, factory: :fellow_user
    course_rise360_module_version
    on_time_credit_received { false }
    canvas_results_url { nil }

    factory 'rise360_module_grade_with_submission' do
      canvas_results_url { 'https://some/submission/url/on/canvas/created/when/opened' }
    end
  end
end
