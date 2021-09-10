# frozen_string_literal: true

require 'canvas_api'

# Represents the "grade" for a Rise360Module See below for why "grade"
# is in quotes.
#
# Note that this doesn't actually store the grade itself. It's computed on
# the fly when needed b/c there are a lot of variables that go into it which
# can change such as an extension being granted or a manual override. The
# main purpose of this model is to map the user to the Canvas assignment so
# we can have an endpoint that will show information about their grade.
# It's analagous to something like a ProjectSubmission but there is no
# "submit" button, hence the "grade" naming
class Rise360ModuleGrade < ApplicationRecord
  belongs_to :user
  belongs_to :course_rise360_module_version
  validates :user, :course_rise360_module_version, presence: true
  scope :with_submissions, -> { where.not canvas_results_url: nil }

  # When the Module is opened for the first time, a placeholder submission
  # is created in Canvas. Returns true if that hasn't happened.
  #
  # See rise360_module_versions_controller#ensure_submission
  def never_opened?
    canvas_results_url.blank?
  end

  # The opposite of never_opened? Returns true if the Module was opened
  # and the submission was created in Canvas that when viewed launches the
  # rise360_module_grade#show view.
  def has_submission?
    canvas_results_url.present?
  end

end
