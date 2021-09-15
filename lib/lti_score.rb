# frozen_string_literal: true

# Represents an LTI score message sent to the API. See:
# https://canvas.instructure.com/doc/api/score.html
#
# Note: the docs for this say to use sub-second precision which differs from
# the CanvasAPI docs. That's why use use iso8601(3) instead of plain iso8601
class LtiScore

  LTI_SCORE_SUBMISSION_URL_KEY = "https://canvas.instructure.com/lti/submission"

  module ActivityProgress
    INITIALIZED='Initialized'
    STARTED='Started'
    IN_PROGRESS='InProgress'
    SUBMITTED='Submitted'
    COMPLETED='Completed'
  end

  module GradingProgress
    NOT_READY = 'NotReady'
    FAILED = 'Failed'
    PENDING = 'Pending'
    PENDING_MANUAL = 'PendingManual'
    FULLY_GRADED = "FullyGraded"
  end

  include ActivityProgress
  include GradingProgress

  # This is weird, but here's what's going on... Canvas will show a big red "Late"
  # indication in the UI depending on the submitted_at time. For Modules, we're just creating
  # a single submission the first time they open the Module. That "Late" indication is
  # meaningless and only shows up if they open the module for the first time after the due date.
  # So we're setting it to Jan 1st, 1970 (the 1 day offset from Epoch 0 is so that anything
  # in the US will be on the 1st instead of Dec 31st 1969 in their local timezone). This way,
  # nothing ever shows as "Late" in the Canvas UI and instead they can see how their grade was
  # calculated by going to the Rise360ModuleGradesController#show endpoint. The submitted_at
  # date is clearly non-sensical so it'll be easier to support questions like
  # "why didn't I get on-time credit when it says Submitted At blah?"
  #
  # To fix this properly, we would need to refactor grading to always create a new submission
  # when they do new work in the Module. It's WAY too much work to do that refactoring.
  # We also talked about using hacky Javascript to hide the "Late" stuff in the UI but it
  # would be nearly impossible to do for only Modules and not Projects as well which would
  # disable our ability to use the Canvas out-of-the box Late Policy Status stuff in the future.
  NON_SENSICAL_SUBMITTED_AT = Time.at(86400).utc.iso8601(3)

  # Generates an LtiScore that represents a new Project submission where
  # a Teaching Assitant or other staff must grade the project.
  def self.new_project_submission(canvas_user_id, submission_url)
    generate(canvas_user_id, SUBMITTED, PENDING_MANUAL, basic_lti_launch_submission(submission_url))
  end

  # Generates an LtiScore that represents a new Module submission where
  # the automatic grading (grade_modules.rake) can update grades to.
  def self.new_module_submission(canvas_user_id, submission_url)

    # You may be tempted to use values like STARTED/PENDING to create this
    # placeholder score/submission, but that would be a mistake. When doing that,
    # if you use the Canvas API (e.g. update_grades) then it causes a 500 error
    # on the Canvas side next time you try to retrieve the score. I think it's bc
    # of the comments in API docs about only PENDING_MANUAL and FULLY_GRADED causing
    # an associated submission to be created for the score line_item.
    generate(canvas_user_id, IN_PROGRESS, PENDING_MANUAL, basic_lti_launch_submission(submission_url, NON_SENSICAL_SUBMITTED_AT))
  end

  # Generates an LtiScore that represents a new submission where no manual
  # grading is needed. The score is for full credit.
  def self.new_full_credit_submission(canvas_user_id, submission_url)
    # The number 100 is arbitrary. This is just full credit: 100/100.
    generate(canvas_user_id, SUBMITTED, FULLY_GRADED, basic_lti_launch_submission(submission_url), 100, 100)
  end

private
  # Params:
  # userId: The lti_user_id or the Canvas user_id
  # scoreGiven: The Current score received in the tool for this line item and user, scaled to
  #             the scoreMaximum
  # scoreMaximum: Maximum possible score for this result; it must be present if scoreGiven is
  #               present.
  # comment: Comment visible to the student about this score.
  # activityProgress: Indicate to Canvas the status of the user towards the activity's completion.
  #                   Must be one of Initialized, Started, InProgress, Submitted, Completed
  # gradingProgress:  Indicate to Canvas the status of the grading process. A value of
  #                   PendingManual will require intervention by a grader. Values of NotReady,
  #                   Failed, and Pending will cause the scoreGiven to be ignored. FullyGraded
  #                   values will require no action. Possible values are NotReady, Failed, Pending,
  #                   PendingManual, FullyGraded
  def self.generate(user_id, activity_progress = COMPLETED, grading_progress = FULLY_GRADED, submission = nil, score_given = nil, score_maximum = nil)
    msg = {
      :userId => user_id.to_s,
      :timestamp => Time.now.utc.iso8601(3),
      :activityProgress => activity_progress,
      :gradingProgress => grading_progress,
    }
    msg[LTI_SCORE_SUBMISSION_URL_KEY] = submission if submission
    msg[:scoreGiven] = score_given if score_given
    msg[:scoreMaximum] = score_maximum if score_maximum
    msg.to_json
  end

  def self.basic_lti_launch_submission(submission_url, submitted_at = Time.now.utc.iso8601(3))
    {
      new_submission: true,
      submission_type: 'basic_lti_launch',
      submission_data: submission_url,
      submitted_at: submitted_at,
    }
  end

end
