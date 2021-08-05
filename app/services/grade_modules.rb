# frozen_string_literal: true

# Grades all Rise360 modules in all "running" courses, for all users.
# This is a class only to follow convention from the rest of our
# services. There is no state maintained in the class between runs.
# This code was refactored out of a rake task and into a service in
# order to make it easier to test. See lib/tasks/grade_modules.rake
# for usage.

require 'time'
require 'module_grade_calculator'

class GradeModules
  def initialize
  end

  def run
    Honeycomb.start_span(name: 'grade_modules.run') do |span|
      # From the list of "running" "programs" in Salesforce, fetch a list of "accelerator"
      # (non-LC) courses.
      canvas_course_ids = SalesforceAPI.client.get_current_and_future_accelerator_canvas_course_ids
      span.add_field('app.grade_modules.canvas_course_ids', canvas_course_ids)
      if canvas_course_ids.empty?
        Rails.logger.info("Exit early: no current/future accelerator programs with a Canvas course ID set.")
        return
      end

      # Eliminate courses with no module interactions, and exit early if that
      # leaves us with an empty list.
      courses = Course.where(canvas_course_id: canvas_course_ids)
        .filter { |c| Rise360ModuleInteraction.where(canvas_course_id: c.canvas_course_id).exists? }
      span.add_field('app.grade_modules.courses.count', courses.count)
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

    Honeycomb.start_span(name: 'grade_modules.grade_course') do |span|
      # We're doing some less-readable queries here because they're drastically
      # more efficient than using the more-readable model associations would be.
      # For reference, the query built by ActiveRecord becomes something like:
      #
      #   SELECT "users_roles"."user_id" FROM "users_roles" WHERE "users_roles"."role_id" IN (
      #     SELECT "roles"."id" FROM "roles" WHERE <...> AND "roles"."resource_id" IN (
      #       SELECT "sections"."id" FROM "sections" WHERE "sections"."course_id" = <course.id>
      #     )
      #   ) GROUP BY "users_roles"."user_id"
      sections = Section.where(course: course)
      roles = Role.where(resource: sections, name: RoleConstants::STUDENT_ENROLLMENT)
      # We're loading all the User IDs into memory right now, so keep an eye out
      # if this needs to be batched or something.
      # NOTE: Don't copy this UserRole code anywhere else unless you *really* need the performance.
      user_ids = UserRole.where(role: roles).group(:user_id).pluck(:user_id)

      canvas_assignment_ids = CourseRise360ModuleVersion
        .where(course: course)
        .pluck(:canvas_assignment_id)

      span.add_field('app.course.id', course.id.to_s)
      span.add_field('app.canvas.course.id', course.canvas_course_id.to_s)
      span.add_field('app.grade_modules.users.count', user_ids.count)
      span.add_field('app.grade_modules.assignments.count', canvas_assignment_ids.count)

      canvas_assignment_ids.each do |canvas_assignment_id|
        # We grab user_ids once outside the assignment loop and pass that list
        # into grade_assignment because grabbing the list of users is slow.
        grade_assignment(canvas_assignment_id, user_ids)
      end
    end
  end

  def grade_assignment(canvas_assignment_id, user_ids)
    Honeycomb.start_span(name: 'grade_modules.grade_assignment') do |span|
      # Select course again, because it's not that expensive and saves us passing it in.
      course = CourseRise360ModuleVersion.find_by(canvas_assignment_id: canvas_assignment_id).course

      span.add_field('app.canvas.assignment.id', canvas_assignment_id.to_s)
      span.add_field('app.canvas.course.id', course.canvas_course_id.to_s)
      span.add_field('app.course.id', course.id.to_s)

      # Initialize map of grades[canvas_user_id] = 'X%'.
      grades = Hash.new

      # Skip assignments with zero interactions; they probably are future ones
      unless Rise360ModuleInteraction.where(canvas_assignment_id: canvas_assignment_id).exists?
        Honeycomb.add_field('grade_modules.skipped_assignment', true)
        Honeycomb.add_field('grade_modules.skipped_reason', 'no interactions for any user')
        Rails.logger.info("Skip canvas_assignment_id = #{canvas_assignment_id}; no interactions")
        return
      end

      # Fetch assignment overrides, one Canvas API call per course/assignment.
      assignment_overrides = CanvasAPI.client.get_assignment_overrides(
        course.canvas_course_id,
        canvas_assignment_id
      )
      # Send all the overrides to Honeycomb, hooray for wide events!
      span.add_field('app.grade_modules.assignment_overrides', assignment_overrides)

      # Select the max id before starting grading, so we can use it at the bottom to mark only things
      # before this as old. If we don't do this, we run the risk of marking things as old that we
      # haven't actually processed yet, causing students to get missing or incorrect grades.
      # NOTE: the `new` column should only be considered an estimate with +/- 1 day resolution.
      max_id = Rise360ModuleInteraction.maximum(:id)
      span.add_field('app.grade_modules.interactions.max_id', max_id.to_s)
      span.add_field('app.grade_modules.users.count', user_ids.count)

      # All users in the course, even if they haven't interacted with this assignment.
      user_ids.each do |user_id|
        Honeycomb.start_span(name: 'grade_modules.grade_user') do
          Honeycomb.add_field('canvas.assignment.id', canvas_assignment_id.to_s)

          # Be careful to only add this to the span (with the prefix) b/c there is not a single
          # "user" associated with this trace. We're instrumenting information about multiple users.
          Honeycomb.add_field('grade_modules.user.id', user_id)

          user = User.find(user_id)
          user.add_to_honeycomb_span('grade_modules')

          interactions = Rise360ModuleInteraction.where(
            user: user,
            canvas_assignment_id: canvas_assignment_id,
            new: true,
          )
          # Note since we only call exists?, the slow `select *` query implied above never actually runs
          # until we've determined that we need to run ModuleGradeCalculator.compute_grade()
          has_new_interactions = interactions.exists?
          Honeycomb.add_field('grade_modules.has_new_interactions', has_new_interactions)

          # If a grade was manually entered in Canvas, that disables all auto-grading logic
          next if GradeModules.grading_disabled_for?(course.canvas_course_id, canvas_assignment_id, user)

          # TODO: fix bug and grade it even if there are no new interactions IFF the due date would change the grade
          # How do we do that efficiently? We want to avoid re-grading nightly which is why we only regrade if
          # there are new interactions. https://app.asana.com/0/1174274412967132/1200247977762040

          # If we're before the due date, and there are no *new* interactions, skip this user.
          due_date = ModuleGradeCalculator.due_date_for_user(user_id, assignment_overrides)
          if !has_new_interactions && !due_date.nil? && Time.parse(due_date) > Time.now.utc
            Honeycomb.add_field('grade_modules.skipped_user', true)
            Honeycomb.add_field('grade_modules.skipped_reason', 'no interactions and assignment isn''t due yet')
            Rails.logger.info("Skip user_id = #{user_id}, canvas_assignment_id = #{canvas_assignment_id}; " \
                "no interactions and assignment isn't due yet")
            next
          end

          # If we get here, we're either before the due date and there are new interactions OR
          # we're after the due date and we grade regardless of interactions so
          # people who skipped this module get auto-zero grades in Canvas.

          Rails.logger.info("Computing grade for: user_id = #{user_id}, canvas_course_id = #{course.canvas_course_id}, " \
              "canvas_assignment_id = #{canvas_assignment_id}")

          # Note: we don't actually store the grade on the rise360_module_grade. We always compute it on the fly
          # b/c there are too many variables that could cause it to change.
          grades[user.canvas_user_id] =
            "#{ModuleGradeCalculator.compute_grade(
              user_id,
              canvas_assignment_id,
              assignment_overrides
            )}%"
        end
      end

      span.add_field('app.grade_modules.grades.count', grades.count)
      # Note: converting grades to string so it doesn't auto-unpack the JSON and
      # fill our schema with crud.
      span.add_field('app.grade_modules.grades', grades.to_s)

      if grades.empty?
        Rails.logger.info("Skip sending grades to Canvas for canvas_assignment_id = #{canvas_assignment_id}; no grades to send")
        return
      end

      # Send grades to Canvas, one API call per course/assignment.
      Rails.logger.info("Sending new grades to Canvas for canvas_course_id = #{course.canvas_course_id}, canvas_assignment_id = #{canvas_assignment_id}")
      CanvasAPI.client.update_grades(course.canvas_course_id, canvas_assignment_id, grades)

      # Mark an *estimate* of the consumed interactions as `new: false`.
      # Some interactions used to calculate grades may not be included in this list.
      Rise360ModuleInteraction.where(
        new: true,
        canvas_course_id: course.canvas_course_id,
        canvas_assignment_id: canvas_assignment_id
      ).where('id <= ?', max_id).update_all(new: false)
    end
  end

  def self.grading_disabled_for?(canvas_course_id, canvas_assignment_id, user)
    rise360_module_grade = CourseRise360ModuleVersion.find_by!(canvas_assignment_id: canvas_assignment_id)
      .rise360_module_grades.find_by(user: user)

    # If they've never opened the module a Rise360ModuleGrade won't exist yet.
    # All auto-grading logic is disabled circuited until they do.
    Honeycomb.add_field('grade_modules.module_opened', rise360_module_grade.present?)
    return true unless rise360_module_grade

    Honeycomb.add_field('grade_modules.grade_manually_overridden', rise360_module_grade.grade_manually_overridden)
    return true if rise360_module_grade.grade_manually_overridden

    # If a TA or staff member manually sets the grade in Canvas, now that's the grade
    # and we turn auto-grading off going forward.
    if CanvasAPI.client
       .latest_submission_manually_graded?(canvas_course_id, canvas_assignment_id, user.canvas_user_id)

      Honeycomb.add_field('grade_modules.grade_manually_overridden_detected_at', DateTime.now.utc)
      Honeycomb.add_field('grade_modules.grade_manually_overridden', true)
      rise360_module_grade.update!(grade_manually_overridden: true)
      return true
    else
      Honeycomb.add_field('grade_modules.grade_manually_overridden', false)
      return false
    end
  end

end
