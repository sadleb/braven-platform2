# frozen_string_literal: true
require 'salesforce_api'
require 'canvas_api'

# Responsible for calculating the grades for the Capstone Evaluation Teamwork assignment and sending grades to Canvas
class GradeCapstoneEvaluations
  include Rails.application.routes.url_helpers

  def initialize(course, lc_course, lti_launch)
    @course = course
    @lc_course = lc_course
    @lti_launch = lti_launch
  end

  def run
    users_to_grade = CapstoneEvaluationSubmissionAnswer.where(submission: new_capstone_eval_submissions)
      .map { |answer| answer.for_user }
      .uniq

    grades = {}

    # Returns all previous submissions for the assignment in the format:
    # { canvas_user_id => submission }
    previous_submissions = CanvasAPI.client.get_assignment_submissions(@course.canvas_course_id, @lti_launch.assignment_id, true)

    users_to_grade.each do |user|
      Honeycomb.start_span(name: 'grade_capstone_evaluation.grade_user') do
        user.add_to_honeycomb_span('grade_capstone_evaluation')

        # grade all capstone eval submissions for given user
        question_scores = grade_capstone_eval_questions(user, true)
        total_score = question_scores.map { |k, v| v }.sum

        grades[user.canvas_user_id] = total_score

        # Create a submission for the Capstone Evaluations Teamwork assignment for the user if they don't already have one
        # we are giving a grade, so they are able to see the grade breakdown from grades
        unless previous_submissions[user.canvas_user_id]
          CanvasAPI.client.create_lti_submission(
            @course.canvas_course_id,
            @lti_launch.assignment_id,
            user.canvas_user_id,
            launch_capstone_evaluation_results_url(protocol: 'https')
          )
        end
      end
    end

    # Unset the Sentry user context so that errors aren't associated with the last user we graded.
    Sentry.set_user({})

    CanvasAPI.client.update_grades(@course.canvas_course_id, @lti_launch.assignment_id, grades)

    new_capstone_eval_submissions.update_all(new: false)
  end

  # Gets the grade breakdown for each question of Capstone Evaluation Peer Reviews
  # Takes in the user to get the breakdown for, and boolean for all submissions
  # True if you want all and false to only get graded submissions
  # When runing the grading service, want to grade users with all submissions
  # When launching the student view, only want to render score with graded submissions
  def grade_capstone_eval_questions(user, all_submissions)
    # Initialize to zero.
    question_scores = {}
    CapstoneEvaluationQuestion.all.each do |question|
      question_scores[question.text] = 0.0
    end

    if all_submissions == true
      submission_answers_for_user = CapstoneEvaluationSubmissionAnswer.where(for_user: user, submission: all_capstone_eval_submissions)
    else
      submission_answers_for_user = CapstoneEvaluationSubmissionAnswer.where(for_user: user, submission: all_capstone_eval_submissions).graded
    end

    # Total by summation.
    submission_answers_for_user.each do |answer|
      question_scores[answer.question.text] += answer.input_value.to_f
    end

    # Divide to get the mean.
    all_questions_count = CapstoneEvaluationQuestion.all.count
    question_scores.each do |k, v|
      # divide the number of total answers a user received for all questions, by the number of questions
      submission_count = submission_answers_for_user.count / all_questions_count
      question_scores[k] = question_scores[k] / submission_count
    end
    question_scores
  end

  def submissions_have_been_graded?
    # If any submissions have been graded for this course, set submissions_have_been_graded to true
    all_capstone_eval_submissions.each do |submission|
      unless submission.new?
        return true
      end
    end

    false
  end

  # Get total score for fellow view
  def fellow_total_score(current_user)
    question_scores = grade_capstone_eval_questions(current_user, false)
    question_scores.map { |k, v| v }.sum
  end

  def user_has_grade?(current_user)
    # user should see their grade if submissions have been graded and their total score is a number
    if submissions_have_been_graded? && !fellow_total_score(current_user).nan?
      return true
    end

    false
  end

  def users_with_published_submissions
    all_capstone_eval_submissions.filter_map { |s| s.user if !s.new }
  end

  def remaining_users
    @course.students_and_lcs - all_capstone_eval_submissions.map { |s| s.user }
  end

  def users_with_new_submissions
    all_capstone_eval_submissions.filter_map { |s| s.user if s.new }
  end

private
  def all_capstone_eval_submissions
    # Merges CapstoneEvaluationSubmissions for Accelerator course and LC course
    return @course.capstone_evaluation_submissions.or(@lc_course.capstone_evaluation_submissions)
  end

  def new_capstone_eval_submissions
    # Merges ungraded CapstoneEvaluationSubmissions for Accelerator course and LC course
    return @course.capstone_evaluation_submissions.ungraded.or(@lc_course.capstone_evaluation_submissions.ungraded)
  end
end
