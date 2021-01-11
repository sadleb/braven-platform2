
# This is created when a Leadership Coach reviews their Fellows in their
# Fellow Evaluation assignment.
class FellowEvaluationSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :course

  validates :user_id, :course_id, presence: true
end
