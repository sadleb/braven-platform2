# frozen_string_literal: true

require 'time'
require 'canvas_api'

# Service to handle the grading logic for a single user's Module assignment.
#
# High-level, we're trying to avoid storing the grade locally b/c it's one more piece of FERPA protected
# PII that we need to safe-guard. Also, since the grade can change at any time for a variety of reasons,
# we want to compute it on the fly whenever possible to avoid complexity with managing cached values.
class GradeRise360ModuleForUser

  # Grading is expensive, so this service will short-circuit running the actual computation if it doesn't
  # need to unless `force_computation` is set true. Also, if you'll be grading in batches you can
  # set `send_grade_to_canvas` to false and handle the necessary steps after calling `run` yourself.
  # See the comments there.
  #
  # Note: the `canvas_submission` will be fetched if it's left nil. Pass it in for optimization reasons.
  def initialize(user, course_rise360_module_version, force_computation = false, send_grade_to_canvas = true, canvas_submission = nil)
    @user = user
    @course_rise360_module_version = course_rise360_module_version
    @send_grade_to_canvas = send_grade_to_canvas
    @force_computation = force_computation
    @existing_canvas_grade = nil # Do this before calling set_canvas_submission() b/c that takes care of initializing it.
    set_canvas_submission(canvas_submission) if canvas_submission.present?

    # Be careful to only add these common fields that are usually in the trace only to this span (with the prefix).
    # there may not be a single user/course/assignment associated with this trace if we're running it for multiple users
    # in the nightly grading task.
    @user.add_to_honeycomb_span('grade_module_for_user')
    Honeycomb.add_field('grade_rise360_module_for_user.canvas.assignment.id', @course_rise360_module_version.canvas_assignment_id.to_s)
    Honeycomb.add_field('grade_rise360_module_for_user.canvas.course.id', @course_rise360_module_version.course.canvas_course_id.to_s)

    @needs_grading = nil
    @existing_canvas_score_display = '-'
    @grader_full_name = nil
    @completed_at = nil
    @completed_at_set = false
    @manually_overridden = nil
    @rise360_module_grade = nil
    @has_new_interactions = nil
    @computed_grade_breakdown = nil
  end

  # Determines if the grade computation should run and if so, runs it and returns the grade
  # as XX% which is suitable for the CanvasAPI. Returns nil if the grading computation didn't
  # need to be run or the grade didn't change after computing it meaning we don't need to update
  # Canvas.
  #
  # Even if this returns nil, the result of the computation will be available through the
  # `computed_grade_breakdown` accessor IFF the computation was run.
  #
  # IMPORTANT: if you intialized this with "send_grade_to_canvas == false", after you call this you
  # MUST do the following yourself after sending the grade(s) to Canvas:
  # 1) if on_time_credit_received? is true on the computed_grade_breakdown, go update that attribute on the
  #    rise360_module_grade. Otherwise, we may keep thinking they got an extension and keep re-grading
  #    them in the nightly task.
  # 2) set the rise360_module_interactions.new attribute to false for all interactions by this user
  #    up to the moment we started running this computation. Otherwise, we'll keep thinking they did
  #    more work in the module and we have to re-grade it.
  def run

    # Select the max id at the very beginning, so we can use it at the bottom to mark only things
    # before this as old. If we don't do this, we run the risk of marking things as old that we
    # haven't actually processed yet, causing students to get missing or incorrect grades.
    max_id = Rise360ModuleInteraction.maximum(:id)

    # Short-circuit the actual grading computation if it's not needed since it's expensive
    # Note that I purposefully always call the more expensive needs_grading?() method even if
    # @force_computation is on. This is so that we send instrumentation information about
    # the grade's status to Honeycomb
    run_computation = needs_grading? || @force_computation
    Honeycomb.add_field('grade_rise360_module_for_user.skipped_computing_grade', !run_computation)
    return nil unless run_computation

    Rails.logger.debug("Computing grade for: user_id = #{@user.id}, " \
      "canvas_course_id = #{@course_rise360_module_version.course.canvas_course_id}, " \
      "canvas_assignment_id = #{@course_rise360_module_version.canvas_assignment_id}")

    @computed_grade_breakdown = ComputeRise360ModuleGrade.new(
      @user,
      @course_rise360_module_version,
      canvas_submission.due_at,
    ).run

    Rails.logger.debug("  - finished: computed grade =  #{@computed_grade_breakdown.inspect}")
    Honeycomb.add_field('grade_rise360_module_for_user.computed_grade', @computed_grade_breakdown.inspect)

    # Only set the grade to send to Canvas if it changed and should be sent.
    grade_for_canvas = nil
    if grade_changed?
      grade_for_canvas = "#{@computed_grade_breakdown.total_grade}%"
      Honeycomb.add_field('grade_rise360_module_for_user.grade_for_canvas', grade_for_canvas)
    end

    # Nothing to send, we're done.
    return nil unless grade_for_canvas

    # Short-circuit sending the grade to Canvas if the consumer of this service has taken responsibility
    # for doing that (likely in batches) and then running the cleanup steps below
    return grade_for_canvas unless @send_grade_to_canvas

    result = CanvasAPI.client.update_grade(
      @course_rise360_module_version.course.canvas_course_id,
      @course_rise360_module_version.canvas_assignment_id,
      @user.canvas_user_id,
      grade_for_canvas
    )
    Honeycomb.add_field('canvas.submission.new', result.to_s)
    Rails.logger.debug("Sent the following submission to Canvas: #{result}")

    # Now that we've sent it to Canvas, auto-grading is back on so reflect that in the
    # grade_is_manually_overridden? method on this instance so we don't show a message in the UI.
    @manually_overridden = false

    # Cache the fact that they received on-time credit for a grade that we successfully sent to Canvas
    # so that future grading doesn't accidentally think they keep receiving an extension.
    rise360_module_grade.update!(on_time_credit_received: true) if computed_grade_breakdown.on_time_credit_received?

    # Set all the work done as "graded".
    Rise360ModuleInteraction.where(
      new: true,
      user: @user,
      canvas_assignment_id: @course_rise360_module_version.canvas_assignment_id,
    ).where('id <= ?', max_id).update_all(new: false)

    grade_for_canvas
  end

  # Scenarios to handle:
  # 1) new interactions -> grade them
  # 2) grade manually overridden -> grade them (if it's higher, use that and turn auto-grading back on)
  # 3) they get an extension of the due date
  # 4) due date has passed and they've never opened it -> grade them (need to 0 out folks)
  def needs_grading?
    return @needs_grading unless @needs_grading.nil?

    @needs_grading = false
    needs_grading_reason = 'Doesn\'t need grading. No new work, no due date extension, not manually overridden, and due date hasn\'t passed.'

    # Failsafe so this doesn't raise and break grading for everyone if we accidentally clear out their canvas_user_id
    if @user.canvas_user_id.blank?
      @needs_grading = false
      needs_grading_reason = 'Doesn\'t need grading. User is missing a canvas_user_id.'
      Honeycomb.add_field('alert.grade_rise360_module_for_user.missing_canvas_user_id', true)

    # If they haven't opened the Module and the due date passes, we need to send a 0 to Canvas.
    elsif needs_zero_grade?
      @needs_grading = true
      needs_grading_reason = 'Needs zero grade. They haven\'t opened the Module and the due date has passed.'

    # Always compute their grade if it was manually overridden in case a staff member accidentally
    # sets it to something lower than the computed value. Also, don't cache it when this happens.
    # Someone could manually grade it at any point and accidentally give a lower grade,
    # even after the module is complete and the Fellow never opens it again.
    elsif grade_is_manually_overridden?
      @needs_grading = true
      needs_grading_reason = 'Grade is manually overridden. Need to make sure its higher than their actual grade.'

    # Grade it if they've interacted with the Module more!
    elsif has_new_interactions?
      @needs_grading = true
      needs_grading_reason = 'New interactions. They have done more work in the Module.'

    # Grade it if they completed the module before the current due date but never got on-time credit
    elsif received_extension?
      @needs_grading = true
      needs_grading_reason = 'Received extension. Module is complete, due date in the future, and they need on-time credit.'

    # Otherwise, we don't need to grade them if they've never opened the Module.
    # Opening it creates an actual submission in Canvas instead of the placeholder that the API always returns
    # for assignments with `basic_lti_launch` as the submission type.
    # See: rise360_module_versions_controller#ensure_submission
    elsif canvas_submission.is_placeholder?
      @needs_grading = false
      needs_grading_reason = 'Doesn\'t need grading. They haven\'t opened the Module and it\'s either not due yet or we already gave it a zero.'
    end

    Honeycomb.add_field('grade_rise360_module_for_user.needs_grading?', @needs_grading)
    Honeycomb.add_field('grade_rise360_module_for_user.needs_grading_reason', needs_grading_reason)

    @needs_grading
  end

  # Returns true if the computed grade is higher than the grade in Canvas and should be sent, else false.
  #
  # Notes:
  # - If no grade exists in Canvas, this also returns true even if the computed grade is 0 (as long as
  #   we did actually compute a grade). It means the due date has passed and we need to send a 0 score.
  # - If the grade in Canvas is higher, we don't want to re-send that same higher grade back. That would
  #   reset the grader_id and we wouldn't know who gave the manual grade which is useful for troubleshooting
  #   and in the UI when folks view the submission. That's why this returns false in that case.
  def grade_changed?
    # If it needed grading, then it most likely changed and should be sent to Canvas.
    grade_changed = needs_grading?

    unless @existing_canvas_grade.nil? || @computed_grade_breakdown.nil?
      # We should never send a lower grade. A TA or admin could accidentally set the grade to something
      # lower manually or there could be edge cases we haven't thought about. Regardless, we want
      # to lean towards always giving the most credit possible.
      grade_changed = @existing_canvas_grade < computed_grade_breakdown.total_grade
    end

    Honeycomb.add_field('grade_rise360_module_for_user.grade_changed?', grade_changed)
    grade_changed
  end

  # Return true if the submission was manually graded by someone and not by the auto-grading code.
  #
  # Note: It's hard to implement this by looking for whether the grader was a TA b/c it could
  # have been an admin or designer or some other role that had permission to edit grades.
  # The easiest way is just to assume that if it wasn't this API user, it was a manual override.
  # If we ever change the API user or accidentally set a manual grade that breaks auto-grading,
  # either write a script or implement an admin tool to fix things up.
  #
  # Note: if the submission has been created using LtiScore.new_pending_manual_submission(),
  # the grader_id will be nil. Don't accidentally treat that as manually graded.
  def grade_is_manually_overridden?
    return @manually_overridden unless @manually_overridden.nil?

    graded_by_id = canvas_submission.canvas_grader_id
    @manually_overridden = (graded_by_id.present? && graded_by_id != CanvasAPI.client.api_user_id)
    @manually_overridden
  end

  # After calling run(), this will hold the breakdown of the grade into it's components and total.
  def computed_grade_breakdown
    raise RuntimeError.new('grade_module_for_user#run was never called') if @computed_grade_breakdown.nil?
    @computed_grade_breakdown
  end

  # Represents the grade (but doesn't actually store it). Used to help determine when we need to recompute
  # the grade and to provide a page where folks can view an "explain grade" breakdown
  def rise360_module_grade
    return @rise360_module_grade if @rise360_module_grade

    # Note: you'll see a bunch of ROLLBACK's in the logs when using create_or_find_by!
    # That's normal and is what makes this an atomic operation vs find_or_create_by! which
    # is not atomic.
    @rise360_module_grade = Rise360ModuleGrade.create_or_find_by!(
      user: @user,
      course_rise360_module_version: @course_rise360_module_version
    )

    Honeycomb.add_field('rise360_module_grade.id', @rise360_module_grade.id)
    Honeycomb.add_field('rise360_module_grade.on_time_credit_received.existing', @rise360_module_grade.on_time_credit_received)

    @rise360_module_grade
  end

  # Returns a string like "4.3 / 10.0" for the total points awarded that is already
  # stored in Canvas on the submission. If it hasn't been graded, returns "- / 10.0"
  def existing_total_points_display
    "#{@existing_canvas_score_display} / #{Rise360Module::POINTS_POSSIBLE.to_f.round(1)}"
  end

  def total_quiz_questions
    @course_rise360_module_version.rise360_module_version.quiz_questions
  end

  # The full name of the person who set the grade on the existing Canvas submission
  # IFF it was manually graded.
  def grader_full_name
    return @grader_full_name if @grader_full_name

    if !grade_is_manually_overridden?
      raise RuntimeError.new('grade_module_for_user#grader_full_name was called for a submission that was not manually graded')
    end

    canvas_user = CanvasAPI.client.show_user_details(@canvas_submission.canvas_grader_id)
    Honeycomb.add_field('canvas.submission.grader', canvas_user)

    @grader_full_name = canvas_user['name']
  end

private

  # True if they've finished the Module before the current due date (which may have changed)
  # and don't already have credit for doing it on-time.
  def received_extension?
    received_extension = false
    unless canvas_submission.due_at.nil?
      received_extension = (
        completed_at.present? &&
        rise360_module_grade.on_time_credit_received == false &&
        canvas_submission.due_at >= completed_at
      )
    end
    received_extension
  end

  # If it's never been graded and the due date passes, we need to send up a 0 to Canvas.
  #
  # Note: there is still the edge case where after they get a 0, if they open it will go
  # back to being ungraded in Canvas until the nightly grading task runs or it's computed
  # on the fly when they view the submission.
  def needs_zero_grade?
    needs_zero_grade = (!canvas_submission.is_graded? && canvas_submission.due_in_past?)
    needs_zero_grade
  end

  # Return true if any new Rise360ModuleInteractions have been received since the last time
  # this was graded.
  #
  # Note: once you finish 100% of a Module, no new interactions will ever be sent even if you click
  # around to prior sections in the Module.
  def has_new_interactions?
    return @has_new_interactions if @has_new_interactions

    @has_new_interactions = Rise360ModuleInteraction.exists?(
      user: @user,
      canvas_assignment_id: @course_rise360_module_version.canvas_assignment_id,
      new: true,
    )
    @has_new_interactions
  end

  # Represents the submission object stored in Canvas.
  def canvas_submission
    return @canvas_submission if @canvas_submission_set
    raw_submission = CanvasAPI.client.get_latest_submission(
      @course_rise360_module_version.course.canvas_course_id,
      @course_rise360_module_version.canvas_assignment_id,
      @user.canvas_user_id
    )
    set_canvas_submission(raw_submission)
  end

  def completed_at
    return @completed_at if @completed_at_set

    @completed_at = Rise360ModuleInteraction.find_by(
      user: @user,
      canvas_assignment_id: @course_rise360_module_version.canvas_assignment_id,
      progress: 100
    )&.created_at

    @completed_at_set = true
    Honeycomb.add_field('grade_rise360_module_for_user.completed_at_date', @completed_at.to_s)
    @completed_at
  end

  def set_canvas_submission(raw_submission)
    Honeycomb.add_field('canvas.submission.existing', raw_submission.to_s)
    @canvas_submission = CanvasSubmission.parse(raw_submission)
    Honeycomb.add_field('canvas.submission.due_at', @canvas_submission.due_at.to_s)
    Honeycomb.add_field('canvas.submission.canvas_grader_id', @canvas_submission.canvas_grader_id.to_s)

    # Parse out the existing grade in an easier format to use for this class
    if @canvas_submission.is_graded?
      # The submission doesn't have the points_possible so we can't determine the grade as a percent
      # without looking at the assignment. See the comments on Rise360Module::POINTS_POSSIBLE for changes
      # we need to make this not be insanely brittle.
      @existing_canvas_grade = 100 * (@canvas_submission.score.to_f / Rise360Module::POINTS_POSSIBLE.to_f)
      Honeycomb.add_field('canvas.submission.existing.grade', "#{@existing_canvas_grade}%")
      @existing_canvas_score_display = @canvas_submission.score.round(1)
    end
    Honeycomb.add_field('canvas.submission.existing.score', @existing_canvas_score_display)

    @canvas_submission_set = true
    @canvas_submission
  end

end
