# frozen_string_literal: true
require 'salesforce_api'

# Responsible for calculating the grades for the Capstone Evaluation Teamwork assignment and sending grades to Canvas
class GradeCapstoneEvaluations
  def initialize(course, lti_launch)
    @course = course
    @lti_launch = lti_launch
  end

  def run
    users_to_grade = CapstoneEvaluationSubmissionAnswer.where(submission: new_capstone_eval_submissions)
      .map { |answer| answer.for_user }
      .uniq

    grades = {}
    users_to_grade.each do |user|
      # grade all capstone eval submissions for given user
      question_scores = grade_capstone_eval_questions(user, true)
      total_score = question_scores.map { |k, v| v }.sum

      grades[user.canvas_user_id] = total_score
    end

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
      submission_answers_for_user = CapstoneEvaluationSubmissionAnswer.where(for_user: user)
    else
      submission_answers_for_user = CapstoneEvaluationSubmissionAnswer.where(for_user: user).graded
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

  def students_with_published_submissions
    all_capstone_eval_submissions.filter_map { |s| s.user if !s.new }
  end

  def remaining_students
    @course.students.uniq - all_capstone_eval_submissions.map { |s| s.user }
  end

  def students_with_new_submissions
    all_capstone_eval_submissions.filter_map { |s| s.user if s.new }
  end

private
  def all_capstone_eval_submissions
    return @course.capstone_evaluation_submissions
  end

  def new_capstone_eval_submissions
    return @course.capstone_evaluation_submissions.ungraded
  end
end
