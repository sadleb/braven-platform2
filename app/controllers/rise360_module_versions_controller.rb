# frozen_string_literal: true

require 'lti_advantage_api'
require 'lti_score'

class Rise360ModuleVersionsController < ApplicationController
  include LtiHelper

  layout 'rise360_container'

  before_action :set_lti_launch, only: [:show]
  before_action :set_course_rise360_module_version, only: [:show]

  # This the LTI launch URL used for Canvas assignments that are Modules.
  # It is similar to CourseResourcesController#lti_show because both
  # CourseResource and Rise360{Version} are backed by Articulate Rise360
  # packages attached to rise360_zipfile on the model.
  # There is nothing here that ties this to the Course that the Module is in.
  # Eventually, we'll use an endpoint on CourseRise360ModuleVersionsController
  # to render this content.
  # TODO: Convert this to use a static endpoint for LTI launch
  # https://app.asana.com/0/1174274412967132/1199352155608256
  def show
    authorize Rise360ModuleVersion
    @rise360_module_version = Rise360ModuleVersion.find(params[:id])
    url = Addressable::URI.parse(@rise360_module_version.launch_url)
    url.query_values = helpers.launch_query
    @launch_path = "#{url.path}?#{url.query}"

    ensure_submission() if is_enrolled_as_student?
  end

private

  # Whenever a student starts working on a Module, we need to ensure that a
  # placeholder submission is there so that if they go to the Grades page,
  # we can show them information about their Module grade.
  #
  # IMPORTANT: if you change this logic, revisit CourseRise360ModuleVersion.has_student_data?
  # which relies on this
  #
  # Note: we have to create this using LtiAdvantage in the context of an
  # LtiLaunch and not using the CanvasAPI from the grade_modules.rake task
  # due to permission errors. If you try to create a new submission for an
  # assignment that is of type 'basic_lti_launch' it will fail with:
  # "user not authorized to perform that action"
  def ensure_submission()
    grade = Rise360ModuleGrade.create_or_find_by!(
      user: current_user,
      course_rise360_module_version: @course_rise360_module_version
    )

    return if grade.has_submission?

    # Note: there is a very unlikely race condition where we could get past the above return line
    # and end up calling the LtiAdvantageAPI twice to create a score / submission. I tested
    # what the behavior is and it's fine. Both API calls succeed, the second one is what
    # the "submitted_at" timestamp would be set to, and the line item's score resultUrl
    # is the same. No need to fix the race condition.

    submission = LtiScore.new_module_submission(
      current_user.canvas_user_id,
      rise360_module_grade_url(
        grade,
        protocol: 'https',
      )
    )

    # Send a submission to Canvas with { activityProgress: Submitted, gradingProgress: PendingManual } and the
    # basic_lti_launch URL set to launch the show() action for this Rise360ModuleGrade
    #
    # Note: there is an edge case here that's too hard to fix. If they never open the Module then this doesn't run.
    # Then, after the due date passes the nightly grading task will use the CanvasAPI to send a 0 grade to Canvas.
    # Finally, if they then go open the Module after that, this LtiAdvantage.create_score() code runs which causes Canvas
    # to clear out the 0 and put it back into an ungraded state. However, the 0 score will be re-sent the next time
    # grading runs.
    score_result = LtiAdvantageAPI.new(@lti_launch).create_score(submission)
    grade.update!(canvas_results_url: score_result['resultUrl'])
  end

  # Only users enrolled as students can create a submission
  # The LTIAdvantageAPI call to Canvas fails for all other enrollments.
  def is_enrolled_as_student?
    @course_rise360_module_version.course.sections.each do |section|
      return true if current_user.has_role? RoleConstants::STUDENT_ENROLLMENT, section
    end
    false
  end

  def set_course_rise360_module_version
    @course_rise360_module_version = CourseRise360ModuleVersion.find_by!(
      canvas_assignment_id: @lti_launch.request_message.canvas_assignment_id,
    )
  end

end
