# frozen_string_literal: true

# Grades all Rise360 modules in all "running" courses, for all users.
# This is a class only to follow convention from the rest of our
# services. There is no state maintained in the class between runs.
# This code was refactored out of a rake task and into a service in
# order to make it easier to test. See lib/tasks/grade_modules.rake
# for usage.

require 'time'
require 'salesforce_api'
require 'canvas_api'

class GradeRise360Modules
  def initialize
  end

  def run
    Honeycomb.start_span(name: 'grade_rise360_modules.run') do
      # From the list of "running" "programs" in Salesforce and those that have recently ended,
      # fetch a list of "accelerator" (non-LC) courses.
      #
      # We also get recently ended programs b/c we want to keep grading until we're sure that
      # the final grades have been sent to the university.
      # https://app.asana.com/0/1201131148207877/1200788567441198
      canvas_course_ids = SalesforceAPI.client
        .get_current_and_future_accelerator_canvas_course_ids(ended_less_than: 45.days.ago)

      Honeycomb.add_field('grade_rise360_modules.canvas_course_ids', canvas_course_ids)
      if canvas_course_ids.empty?
        Rails.logger.info("Exit early: no current/future accelerator programs with a Canvas course ID set.")
        return
      end

      # Eliminate courses with no module interactions, and exit early if that
      # leaves us with an empty list.
      courses = Course.where(canvas_course_id: canvas_course_ids)
        .filter { |c| Rise360ModuleInteraction.where(canvas_course_id: c.canvas_course_id).exists? }
      Honeycomb.add_field('grade_rise360_modules.courses.count', courses.count)
      if courses.empty?
        Rails.logger.info("Exit early: no accelerator courses with interactions")
        return
      end

      # From the remaining courses, compute grades for all modules/users.
      courses.each do |course|
        grade_course(course)
      end
    end
  end

  def grade_course(course)

    Honeycomb.start_span(name: 'grade_rise360_modules.grade_course') do
      Honeycomb.add_field('course.id', course.id.to_s)
      Honeycomb.add_field('canvas.course.id', course.canvas_course_id.to_s)

      # We're doing some less-readable queries here because they're drastically
      # more efficient than using the more-readable model associations would be.
      # For reference, the query built by ActiveRecord becomes something like:
      #
      #   SELECT "users_roles"."user_id" FROM "users_roles" 
      #     INNER JOIN "users" "user" ON "user"."id" = "users_roles"."user_id" 
      #   WHERE "users_roles"."role_id" IN (
      #     SELECT "roles"."id" FROM "roles" WHERE <...> AND "roles"."resource_id" IN (
      #       SELECT "sections"."id" FROM "sections" WHERE "sections"."course_id" = <course.id>
      #     )
      #   ) AND "user"."registered_at" IS NOT NULL
      #   GROUP BY "users_roles"."user_id"
      sections = Section.where(course: course)
      roles = Role.where(resource: sections, name: RoleConstants::STUDENT_ENROLLMENT)
      # We're loading all the User IDs into memory right now, so keep an eye out
      # if this needs to be batched or something.
      # NOTE: Don't copy this UserRole code anywhere else unless you *really* need the performance.
      user_ids = UserRole.joins(:user).where(role: roles).where.not(user: {registered_at: nil})
        .group(:user_id).pluck(:user_id)

      Honeycomb.add_field('grade_rise360_modules.users.count', user_ids.count)

      canvas_assignment_ids = CourseRise360ModuleVersion
        .where(course: course)
        .pluck(:canvas_assignment_id)
      Honeycomb.add_field('grade_rise360_modules.assignments.count', canvas_assignment_ids.count)

      canvas_assignment_ids.each do |canvas_assignment_id|
        # We grab user_ids once outside the assignment loop and pass that list
        # into grade_assignment because grabbing the list of users is slow.
        grade_assignment(canvas_assignment_id, user_ids)
      end

    rescue => e
      msg = "Module Auto-grading failed for course '#{course.name}' (canvas_course_id=#{course.canvas_course_id}). "+
            "Grades for this course may be out-of-date until this is resolved."
      Honeycomb.add_alert('grade_rise360_modules_for_course_failed', msg)
    end
  end

  def grade_assignment(canvas_assignment_id, user_ids)
    Honeycomb.start_span(name: 'grade_rise360_modules.grade_assignment') do
      crmv = CourseRise360ModuleVersion.find_by(canvas_assignment_id: canvas_assignment_id)
      course = crmv.course

      Honeycomb.add_field('canvas.assignment.id', canvas_assignment_id.to_s)
      Honeycomb.add_field('canvas.course.id', course.canvas_course_id.to_s)
      Honeycomb.add_field('course.id', course.id.to_s)

      # Initialize map of grades[canvas_user_id] = 'X%'.
      grades = Hash.new

      # Array to store the Rise360ModuleGrade.id's that got credit for their on-time grade which
      # we need to save back to the local database after we send grades to Canvas.
      on_time_credit_model_ids = []

      # Skip assignments with zero interactions; they probably are future ones
      unless Rise360ModuleInteraction.where(canvas_assignment_id: canvas_assignment_id).exists?
        Honeycomb.add_field('grade_rise360_modules.skipped_assignment', true)
        Honeycomb.add_field('grade_rise360_modules.skipped_reason', 'no interactions for any user')
        Rails.logger.info("Skip canvas_assignment_id = #{canvas_assignment_id}; no interactions")
        return
      end

      # Fetch assignment submissions, one Canvas API call per course/assignment.
      submissions = CanvasAPI.client.get_assignment_submissions(
        course.canvas_course_id,
        canvas_assignment_id
      )

      # Send all the submissions to Honeycomb, hooray for wide events!
      Honeycomb.add_field('grade_rise360_modules.submissions', submissions)

      # Select the max id before starting grading, so we can use it at the bottom to mark only things
      # before this as old. If we don't do this, we run the risk of marking things as old that we
      # haven't actually processed yet, causing students to get missing or incorrect grades.
      # NOTE: the `new` column should only be considered an estimate with +/- 1 day resolution.
      max_id = Rise360ModuleInteraction.maximum(:id)
      Honeycomb.add_field('grade_rise360_modules.interactions.max_id', max_id.to_s)
      Honeycomb.add_field('grade_rise360_modules.users.count', user_ids.count)

      # All users in the course, even if they haven't interacted with this assignment.
      user_ids.each do |user_id|
        Honeycomb.start_span(name: 'grade_rise360_modules.grade_user') do
          user = User.find(user_id)

          # Note that there will be a submission for every student even if they've never opened the
          # assignment. See CanvasSubmission#is_placeholder? for more info.
          grade_user_service = GradeRise360ModuleForUser.new(user, crmv, false, false, submissions[user.canvas_user_id])

          grade_for_canvas = grade_user_service.run()
          if grade_user_service.grade_changed?
            grades[user.canvas_user_id] = grade_for_canvas
            if grade_user_service.computed_grade_breakdown.on_time_credit_received?
              on_time_credit_model_ids << grade_user_service.rise360_module_grade.id
            end
          end
        end

      end

      # Unset the Sentry user context so that errors aren't associated with the last user we graded.
      Sentry.set_user({})

      Honeycomb.add_field('grade_rise360_modules.grades.count', grades.count)
      # Note: converting grades to string so it doesn't auto-unpack the JSON and
      # fill our schema with crud.
      Honeycomb.add_field('grade_rise360_modules.grades', grades.to_s)

      if grades.empty?
        Rails.logger.info("Skip sending grades to Canvas for canvas_assignment_id = #{canvas_assignment_id}; no grades to send")
        return
      end

      # Send grades to Canvas, one API call per course/assignment.
      Rails.logger.info("Sending new grades to Canvas for canvas_course_id = #{course.canvas_course_id}, canvas_assignment_id = #{canvas_assignment_id}")
      CanvasAPI.client.update_grades(course.canvas_course_id, canvas_assignment_id, grades)

      # Now that we've successfully finished grading and sent them to Canvas, update all those
      # who got credit for doing the module on-time so that we can determine if they need to be
      # re-graded in the future if they get a due date extension.
      Rise360ModuleGrade.where(id: on_time_credit_model_ids).update_all(on_time_credit_received: true) unless on_time_credit_model_ids.empty?

      # Mark an *estimate* of the consumed interactions as `new: false`.
      # Some interactions used to calculate grades may not be included in this list.
      Rise360ModuleInteraction.where(
        new: true,
        canvas_assignment_id: canvas_assignment_id
      ).where('id <= ?', max_id).update_all(new: false)
    end
  end

end
