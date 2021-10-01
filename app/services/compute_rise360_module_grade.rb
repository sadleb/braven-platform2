# frozen_string_literal: true

require 'time'

# Service to run the raw computation of the grade for a Rise360Module for a user.
class ComputeRise360ModuleGrade
  ComputeRise360ModuleGradeError = Class.new(StandardError)

  # Relative weights for module grading.
  # Must add up to 1.0.
  GRADE_WEIGHTS = {
    module_engagement: 0.4,
    mastery_quiz: 0.4,
    on_time: 0.2,
  }

  # Note: a Rise360 package has the same activity ID when you update it and
  # export it again. This means, we can have multiple Rise360ModuleVersions with
  # the same activity ID. That's why we use the @course_rise360_module_version
  def initialize(user, course_rise360_module_version, due_date)
    @user = user
    @course_rise360_module_version = course_rise360_module_version
    @due_date = due_date
    @total_quiz_questions = nil
    @correct_quiz_answers = nil
  end

  # Compute the grade and returns a ComputedGradeBreakdown
  #
  # Note: this ignores all logic about whether grading should happen and what what to grade.
  # It computes the grade from all of the records for the user and the module.
  # The caller should do any logic to determine whether the computation is
  # necessary. See: grade_rise360_module_for_user.rb
  def run
    Honeycomb.start_span(name: 'compute_rise360_module_grade.run') do

      # Note: If a content designer publishes a new Rise360 package to the same
      # assignment, all old interactions are technically invalidated. But we
      # can't easily detect that here, so make sure outdated interactions are
      # handled elsewhere in the Rise360Module-related code.
      interactions = Rise360ModuleInteraction.where(
        canvas_assignment_id: @course_rise360_module_version.canvas_assignment_id,
        user: @user,
      )

      # If there are no interactions, exit early with a zero grade.
      # exists? is the fastest check when records aren't preloaded.
      unless interactions.exists?
        Honeycomb.add_field('compute_rise360_module_grade.interactions.count', 0)
        Honeycomb.add_field('compute_rise360_module_grade.grade', 0)
        return ComputedGradeBreakdown.new(0,0,0)
      end

      # Start computing grades.
      Honeycomb.add_field('compute_rise360_module_grade.interactions.count', interactions.count)
      progressed_interactions = interactions.where(verb: Rise360ModuleInteraction::PROGRESSED)

      engagement_grade = grade_module_engagement(progressed_interactions)

      on_time_grade = grade_completed_on_time(progressed_interactions)

      completed_at = module_completed_at(progressed_interactions)

      # NOTE: Always use Rise360ModuleVersion.quiz_questions for this calculation,
      # since the base Module might have different questions than this Version.
      @total_quiz_questions = @course_rise360_module_version.rise360_module_version.quiz_questions
      Honeycomb.add_field('compute_rise360_module_grade.quiz_questions_total', @total_quiz_questions)

      quiz_grade = nil
      if @total_quiz_questions && @total_quiz_questions > 0
        quiz_grade = grade_mastery_quiz(interactions.where(verb: Rise360ModuleInteraction::ANSWERED))
      end

      return ComputedGradeBreakdown.new(engagement_grade, quiz_grade, on_time_grade, completed_at)
    end
  end

  # Represents the result of a grade computation broken down into it's various components.
  # Responsible for turning the component grades into their corresponding raw scores as well
  # as providing access to the total_score.
  class ComputedGradeBreakdown
    attr_reader :total_score, :engagement_score, :quiz_score, :on_time_score, :engagement_grade, :quiz_grade, :completed_at

      POINTS_POSSIBLE = {
        module_engagement: (GRADE_WEIGHTS[:module_engagement] * Rise360Module::POINTS_POSSIBLE).round(1),
        mastery_quiz: (GRADE_WEIGHTS[:mastery_quiz] * Rise360Module::POINTS_POSSIBLE).round(1),
        on_time: (GRADE_WEIGHTS[:on_time] * Rise360Module::POINTS_POSSIBLE).round(1)
      }

    def initialize(engagement_grade, quiz_grade, on_time_grade, completed_at = nil)
       @completed_at = completed_at
       @engagement_grade = engagement_grade
       effective_engagement_weight = GRADE_WEIGHTS[:module_engagement]
       # If there are no mastery questions to grade. Full grade is just engagement + on time
       effective_engagement_weight += GRADE_WEIGHTS[:mastery_quiz] if quiz_grade.nil?
       @engagement_score = get_score(effective_engagement_weight, engagement_grade)
       @quiz_grade = quiz_grade
       @quiz_score = get_score(GRADE_WEIGHTS[:mastery_quiz], quiz_grade) unless quiz_grade.nil?
       @on_time_grade = on_time_grade
       @on_time_score = get_score(GRADE_WEIGHTS[:on_time], on_time_grade)

       # Note: we calculate by adding the rounded components to ensure that the total
       # matches the rounded components.
       @total_score = @engagement_score + @on_time_score
       @total_score += @quiz_score unless quiz_grade.nil?

       # Still have to round b/c floating point numbers are imprecise and adding something like
       # the following can still end up with trailing decimals:
       # 0.1 + 2.0 + 0.8 = 2.9000000000000004
       # See here for more context: https://stackoverflow.com/questions/13847917/ruby-floats-add-up-to-different-values-depending-on-the-order
       @total_score = @total_score.round(1)
    end

    def on_time_credit_received?
      @on_time_grade > 0
    end

    # Returns a string like "0.0 / 2.0" or "2.0 / 2.0" for the points they were awarded out of the max
    # they can get for the on-time portion of the grade.
    def on_time_points_display
      "#{@on_time_score} / #{POINTS_POSSIBLE[:on_time]}"
    end

    # Returns a string like "3.3 / 4.0" for the points they were awarded out of the max
    # they can get for the engagement portion of the grade.
    def engagement_points_display
      "#{@engagement_score} / #{POINTS_POSSIBLE[:module_engagement]}"
    end

    # Returns a string like "3.3 / 4.0" for the points they were awarded out of the max
    # they can get for the mastery quiz portion of the grade.
    def mastery_points_display
      return 'N/A' if @quiz_grade.nil? # This shouldn't happen. Let's just be safe if a Module doesn't have mastery questions

      "#{@quiz_score} / #{POINTS_POSSIBLE[:mastery_quiz]}"
    end

    # Returns a string like "3.3 / 10.0" for the total points they were awarded
    def total_points_display
      "#{@total_score} / #{Rise360Module::POINTS_POSSIBLE}"
    end

    def ==(other)
      return self.engagement_score == other.engagement_score &&
             self.quiz_score == other.quiz_score &&
             self.on_time_score == other.on_time_score &&
             self.completed_at == other.completed_at
    end
  private
    def get_score(weight, grade)
      percent_of_grade_awarded = weight * (grade.to_f / 100)
      (Rise360Module::POINTS_POSSIBLE * percent_of_grade_awarded).round(1)
    end
  end


private

  # Returns [0, 100] for user's progress in a module.
  def grade_module_engagement(interactions)
    interactions.maximum(:progress) || 0
  end

  # Returns [0, 100] for number of questions user got right out of the
  # questions in the module.
  def grade_mastery_quiz(interactions)
    if @total_quiz_questions.nil? || @total_quiz_questions.zero?
      raise ComputeRise360ModuleGradeError, "Error grading mastery quizzes. No questions found. (total_questions = #{@total_quiz_questions})"
    end

    most_recent = interactions
      .group(activity_id_without_timestamp)
      .maximum(:created_at)
      .to_h
      .values

    # Number of correct answers from most recent interactions.
    @correct_quiz_answers = interactions
      .where(
        created_at: most_recent,
        success: true,
      )
      .count
    Honeycomb.add_field('compute_rise360_module_grade.quiz_questions_correct', @correct_quiz_answers)

    100 * (@correct_quiz_answers.to_f / @total_quiz_questions.to_f)
  end

  # Returns 0 *or* 100, representing whether the user reached 100%
  # progression before the due date.
  def grade_completed_on_time(interactions)
    # Use due_date unless it's nil, then fall back to current date.
    due_date_obj = @due_date.nil? ? Time.now.utc : @due_date

    on_time_progress = interactions.where('created_at <= ?', due_date_obj)
      .order(:created_at)
      .last
      &.progress

    if on_time_progress.nil? or on_time_progress < 100
      0
    else
      100
    end
  end

  # Returns created_at (as a ActiveSupport::TimeWithZone) for the 100% progress interaction,
  # if it exists, otherwise returns nil.
  def module_completed_at(interactions)
    # There shouldn't ever be more than one, but select the earliest
    # one anyway just in case.
    interactions.where(progress: 100)
      .order(:created_at)
      .first
      &.created_at
  end

  # Returns SQL that strips off _<timestamp> from the activity_id.
  def activity_id_without_timestamp
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
