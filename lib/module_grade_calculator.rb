# frozen_string_literal: true

class ModuleGradeCalculator
  ModuleGradeCalculatorError = Class.new(StandardError)

  MODULE_ENGAGEMENT_WEIGHT = 0.5

  # Relative weights for module grading
  def self.grade_weights
    {
      module_engagement: MODULE_ENGAGEMENT_WEIGHT,
      mastery_quiz: 1.0 - MODULE_ENGAGEMENT_WEIGHT,
    }
  end

  # Returns [0, 100] for user's total grade for a module.
  # Note: this ignores "new" on Rise360ModuleInteraction and computes the grade from 
  # all of the records for the user and the module.
  # The caller should do any logic to determine whether the computation is 
  # necessary. For an example, see:
  #   lib/tasks/grade_modules.rake
  def self.compute_grade(user_id, canvas_assignment_id, activity_id)

    interactions = Rise360ModuleInteraction.where(
      "canvas_assignment_id = ? AND user_id = ? AND activity_id LIKE ?",
      canvas_assignment_id,
      user_id,
      "#{activity_id}%",
    )

    engagement_grade = grade_module_engagement(
      interactions.where(verb: Rise360ModuleInteraction::PROGRESSED),
    )

    # Note: a Rise360 package has the same activity ID when you update it and
    # export it again. This means, we can multiple Rise360ModuleVersions with
    # the same activity ID. That's why we use the canvas_assignment_id to find the
    # the correct version.
    crmv = CourseRise360ModuleVersion.find_by!(canvas_assignment_id: canvas_assignment_id)
    rmv = Rise360ModuleVersion.find(crmv.rise360_module_version_id)
    total_quiz_questions = rmv.quiz_questions

    if total_quiz_questions && total_quiz_questions > 0
      quiz_grade = grade_mastery_quiz(
        interactions.where(verb: Rise360ModuleInteraction::ANSWERED),
        total_quiz_questions,
      )

      (
        grade_weights[:module_engagement] * engagement_grade +
        grade_weights[:mastery_quiz] * quiz_grade
      )
    else
      # Skip the mastery portion of the grade if there are no mastery questions.
      engagement_grade
    end
  end

  # Returns [0, 100] for user's progress in a module.
  def self.grade_module_engagement(interactions)
    interactions.maximum(:progress) || 0
  end

  # Returns [0, 100] for number of questions user got right out of the
  # questions in the module.
  def self.grade_mastery_quiz(interactions, total_questions)
    if total_questions.nil? || total_questions.zero?
      raise ModuleGradeCalculatorError, "Error grading mastery quizzes. No questions found. (total_questions = #{total_questions})"
    end

    most_recent = interactions
      .group(activity_id_without_timestamp)
      .maximum(:created_at)
      .to_h
      .values

    # Number of correct answers from most recent interactions.
    correct_answers = interactions
      .where(
        created_at: most_recent,
        success: true,
      )
      .count

    100 * (correct_answers.to_f / total_questions.to_f)
  end

  # Returns SQL that strips off _<timestamp> from the activity_id.
  def self.activity_id_without_timestamp
    # The activity_id for ANSWERED interactions have the format:
    #   MY_ACTIVITY_ID/some_unique_quiz_id/some_unique_question_id_timestamp

    # We need to reverse the activity_id to find the final _ character that
    # precedes the timestamp
    activity_id = "REVERSE(activity_id)"

    # This gives us the index of _ before <timestamp>
    idx = "POSITION('_' IN #{activity_id})"

    # This strips off _<timestamp> from the activity_id
    substring = "SUBSTRING(#{activity_id}, #{idx} + 1)"

    # Remember we were operating on the reversed activity_id, so flip it around
    # to make it human readable again
    "REVERSE(#{substring})"
  end
end
