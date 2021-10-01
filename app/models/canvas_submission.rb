# frozen_string_literal: true

class CanvasSubmission < ApplicationRecord
  self.primary_key = 'canvas_submission_id'

  # Parses the hash created from the CanvasAPI json response into a CanvasSubmission model.
  def self.parse(submission)
    CanvasSubmission.new(parse_attributes(submission))
  end

  # Parses the hash created from the CanvasAPI json response into hash matching
  # the attributes for this model.
  def self.parse_attributes(submission, canvas_course_id = nil)
    {
      canvas_submission_id: submission['id'],
      canvas_assignment_id: submission['assignment_id'],
      canvas_user_id: submission['user_id'],
      canvas_course_id: canvas_course_id,
      canvas_grader_id: submission['grader_id'],
      score: submission['score'],
      grade: submission['grade'],
      graded_at: submission['graded_at'],
      late: submission['late'],
      submission_type: submission['submission_type'],

      # Note: Through extensive testing of various permutations of setting a due date for "Everyone",
      # for a particular Section, and for a particular Student the `cached_due_date` appears to
      # always get set to the effective due date for that user correctly. If that turns out not
      # to be the case, we'll have to put logic back in that goes through the assignment overrides
      # and calculates the due date manually.
      due_at: (submission['cached_due_date'] ? Time.parse(submission['cached_due_date']) : nil),
    }
  end

  # When a Module, Project, etc is created as a `basic_lti_launch` assignment, a placeholder submission
  # is returned by the API for every user even if they've never submitted it (or opened a Module and had
  # the auto-grading code submit something). These submissions correspond to the page that shows
  # "No Preview Available" when someone tries to view it b/c nothing has actually been submitted yet.
  def is_placeholder?
    submission_type.nil?
  end

  def is_graded?
    # Note: don't use the `graded_at` field. If there is a placeholder submission and we send
    # a 0 grade through the API, it's been graded with a 0. BUT if a real submission is then created,
    # the score is set back to nil but graded_at is still set to the timestamp when we sent the 0 and
    # grade_matches_current_submission is set to false.
    !score.nil?
  end

  # True if a due_date is set and it's in the past, else false.
  def due_in_past?
    !due_at.nil? && due_at <= Time.now.utc
  end

end
