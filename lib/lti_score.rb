# frozen_string_literal: true

# Represents an LTI score message sent to the API. See:
# https://canvas.instructure.com/doc/api/score.html
class LtiScore
  
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
  def self.generate(user_id, score_given, score_maximum, activity_progress = COMPLETED, grading_progress = FULLY_GRADED, comment = nil)
    {
      :userId => user_id,
      :scoreGiven => score_given,
      :scoreMaximum => score_maximum,
      :comment => comment,
      :timestamp => DateTime.now,
      :activityProgress => activity_progress,
      :gradingProgress => grading_progress 
      # TODO: add the option to send a submmission type and the data for the submission.
      # See the following key in the docs
      # 'https://canvas.instructure.com/lti/submission' => {TODO}
    }.to_json
  end


end
