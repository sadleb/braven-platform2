# frozen_string_literal: true

class RateThisModuleSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :course_rise360_module_version

  has_one :course, through: :course_rise360_module_version
  has_one :rise360_module_version, through: :course_rise360_module_version
  has_many :rate_this_module_submission_answers
  alias_attribute :answers, :rate_this_module_submission_answers

  validates :user, :course_rise360_module_version, presence: true
  validates :user, uniqueness: { scope: :course_rise360_module_version_id }

  # Takes a hash like:
  #   { input_name => input_value }
  # and adds each key:value pair as RateThisModuleSubmissionAnswers to this submission.
  def save_answers!(answers_hash)
    transaction do
      answers_hash.map do |input_name, input_value|
        answer = RateThisModuleSubmissionAnswer.find_or_create_by!(
          input_name: input_name,
          rate_this_module_submission: self,
        )
        answer.update!(input_value: input_value)
      end
    end
    self
  end
end
