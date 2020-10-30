# This it our custom key-value (e.g., input name and input value) model for 
# storing responses to impact survey submissions. 
# This is **not** a general-purpose key-value store.
# Please do not introduce the bz-retained-data nightmare.
class SurveySubmissionAnswer < ApplicationRecord
  belongs_to :survey_submission

  has_one :survey_version, -> { survey_version }, through: :survey_submission
end
