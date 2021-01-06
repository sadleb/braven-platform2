# frozen_string_literal: true

# This is not an ApplicationModel because there's no corresponding table, e.g.
# `accelerator_survey_submissions`, backing it.
# This behaves like an ActiveModel so we can use `Submittable` in the
# AcceleratorSurveySubmissionsController and with our AcceleratorySurveyPolicy.
class AcceleratorSurveySubmission
  include ActiveModel::Model

  attr_accessor :user, :course

  # For Submittable
  def save_answers!(_input_values_by_user_and_question)
    # We don't save the submission or their answers in our DB.
    # These surveys are handled by FormAssembly, which store the responses.
  end
end
