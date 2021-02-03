# frozen_string_literal: true

class RateThisModuleSubmissionAnswer < ApplicationRecord
  belongs_to :rate_this_module_submission
  alias_attribute :submission, :rate_this_module_submission

  has_one :user, through: :rate_this_module_submission

  validates :input_name, presence: true
  validates :input_name, uniqueness: { scope: :rate_this_module_submission_id }
end
