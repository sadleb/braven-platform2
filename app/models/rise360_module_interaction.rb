# frozen_string_literal: true
class Rise360ModuleInteraction < ApplicationRecord
  PROGRESSED = 'http://adlnet.gov/expapi/verbs/progressed'
  ANSWERED = 'http://adlnet.gov/expapi/verbs/answered'

  belongs_to :user
  validates :user, :activity_id, :verb, :canvas_course_id, :canvas_assignment_id, presence: true

  # Use this method to create progress interactions and kick off grading for the Module
  # if necessary.
  #
  # Note that calling this twice for a given progress will only create a single
  # interaction for the target user/course/assignment/module. This is especially important
  # for the 100% completion interaction since that represents when they "submitted" the Module.
  # It's more straightforward to have only one for the "completed_at" date.
  def self.create_progress_interaction(user, lti_launch, activity_id, progress)

    # Note: conceivably the activity_id could change if we publish a new Module,
    # but we blow away all interactions so that shouldn't be a problem. It's cleaner
    # to use the same attributes for find and create even though user and canvas_assignment_id
    # should be enough to determine if we need to create a new progress.
    # TODO: add a DB constraint: https://app.asana.com/0/1174274412967132/1201176917466766
    attributes = {
      verb: PROGRESSED,
      user: user,
      canvas_course_id: lti_launch.course_id,
      canvas_assignment_id: lti_launch.assignment_id,
      activity_id: activity_id,
      progress: progress,
    }

    existing_progress_interaction = Rise360ModuleInteraction.find_by(attributes)

    # This method can be called more than once for a given progress. E.g. if they jump back
    # and then forward again using the sidebar or if they scroll to the bottom of the Module
    # after submitting Rate This Module for the 100% case. The second time is a NOOP since we
    # only care about the original progress for grading purposes.
    return existing_progress_interaction if existing_progress_interaction.present?

    # There is a race condition here but we don't care if the second call fails since it
    # should have been a NOOP anyway. Just return nil.
    interaction = Rise360ModuleInteraction.create(attributes)
    Honeycomb.add_field('create_progress_interaction', interaction.inspect)

    # Grade it now if they're done instead of waiting for the nightly task so that they
    # immediately see they get credit and feel good about that.
    if progress == 100 && interaction
      GradeRise360ModuleForUserJob.perform_later(user, lti_launch)
    end

    interaction
  end

  def root_activity_id
    if verb == ANSWERED
      # Remove the /quiz_id/question_id part.
      # Activity IDs for Rise360 ANSWERED verbs *usually* look something like:
      #   http://OrDngAKqbvX4sCs0vBpsk-P1VXsst1vc_rise/quiz-id/question-id_timestamp
      # However, the "root" ID is user-controlled, so we can't guarante we won't
      # get something like this instead:
      #   http://a/bunch/of/things/quiz-id/question-id_timestamp
      # Because we can only rely on the end of the string being consistent, we
      # say here "starting at the end, remove up to the second slash". That will
      # always give us the root activity ID, regardless of what that root looks like.
      activity_id.split('/')[0..-3].join('/')
    else
      activity_id
    end
  end
end
