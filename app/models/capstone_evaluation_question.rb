class CapstoneEvaluationQuestion < ApplicationRecord
  # TODO: this constant is used to convert between scores and percents in the grading
  # code. To make this not be insanely brittle, we should actually use this to set
  # the points_possible when we publish the assignment.
  # https://app.asana.com/0/1174274412967132/1199231117515061
  TOTAL_POINTS_POSSIBLE=40.0
  POINTS_POSSIBLE=10.0

  before_destroy :four_question_warning
  after_create :four_question_warning

  has_many :capstone_evaluation_submission_answers
  alias_attribute :answers, :capstone_evaluation_submission_answers

  validates :text, presence: true

  # The GROUP PROJECT: Capstone Challenge: Teamwork assignment score is based on there being 4 questions for fellows
  # to evaluate their teammates on. If the number of questions is changed it will mess up the scoring.
  def four_question_warning
    Rails.logger.warn('There should always be exactly four Capstone Evaluation Questions. Do not add or remove any questions as it will affect grade calculations')
   end

end
