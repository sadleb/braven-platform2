# frozen_string_literal: true

require 'canvas_api'
require 'salesforce_api'

class SyncCanvasGrades

  def initialize
  end

  def run
    canvas_course_ids = SalesforceAPI.client.get_current_and_future_accelerator_canvas_course_ids
    Honeycomb.add_field('sync_canvas_grades.courses.count', canvas_course_ids.count)
    Rails.logger.info("Found #{canvas_course_ids.count} courses")

    canvas_course_ids.each do |canvas_course_id|
      Honeycomb.start_span(name: 'sync_submissions') do
        Honeycomb.add_field('canvas.course.id', canvas_course_id.to_s)
        # Sync grades.
        Rails.logger.info("Syncing grades for canvas_course_id=#{canvas_course_id}")
        submissions = CanvasAPI.client.get_submission_data(canvas_course_id)
        Honeycomb.add_field('sync_canvas_grades.submissions.count', submissions.count)
        Rails.logger.info("Found #{submissions.count} submissions")
        submissions.each do |submission|
          Rails.logger.info("Syncing canvas_submission_id=#{submission['id']}")
          data = {
            canvas_submission_id: submission['id'],
            canvas_assignment_id: submission['assignment_id'],
            canvas_user_id: submission['user_id'],
            canvas_course_id: canvas_course_id,
            score: submission['score'],
            grade: submission['grade'],
            graded_at: submission['graded_at'],
            late: submission['late'],
          }
          CanvasSubmission.upsert(data, unique_by: [:canvas_submission_id])

          if submission['rubric_assessment']
            Honeycomb.add_field('sync_canvas_grades.rubric_assessments.count', submission['rubric_assessment'].length)
            Rails.logger.info("Found #{submission['rubric_assessment'].length} rubric_assessments")
            submission['rubric_assessment'].each do |canvas_criterion_id, assessment_value|
              Rails.logger.info("Syncing rating for canvas_submission_id=#{data[:canvas_submission_id]}, canvas_rating_id=#{assessment_value['rating_id']}")

              # Sometimes the rating id is nil. Only seen this on one test user,
              # so maybe an isolated case? Send some stats to Honeycomb just in case.
              unless assessment_value['rating_id']
                Honeycomb.add_field('sync_canvas_grades.no_rating_id', true)
                Honeycomb.add_field('sync_canvas_grades.assessment_value', assessment_value)
                next
              end

              rating_data = {
                canvas_submission_id: data[:canvas_submission_id],
                canvas_criterion_id: canvas_criterion_id,
                canvas_rating_id: assessment_value['rating_id'],
                comments: assessment_value['comments'],
                points: assessment_value['points'],
              }
              CanvasSubmissionRating.upsert(rating_data, unique_by: [
                :canvas_submission_id, :canvas_rating_id, :canvas_criterion_id
              ])
            end
          end
        end
      end

      # Sync course rubrics.
      Honeycomb.start_span(name: 'sync_rubrics') do
        Honeycomb.add_field('canvas.course.id', canvas_course_id.to_s)
        Rails.logger.info("Syncing rubrics for canvas_course_id=#{canvas_course_id}")
        rubrics = CanvasAPI.client.get_course_rubrics_data(canvas_course_id)
        Honeycomb.add_field('sync_canvas_grades.rubrics.count', rubrics.count)
        Rails.logger.info("Found #{rubrics.count} rubrics")
        sync_rubrics(rubrics)
      end
    end

    # Sync account rubrics.
    Honeycomb.start_span(name: 'sync_account_rubrics') do
      Rails.logger.info("Syncing rubrics for account")
      rubrics = CanvasAPI.client.get_account_rubrics_data()
      Honeycomb.add_field('sync_canvas_grades.rubrics.count', rubrics.count)
      Rails.logger.info("Found #{rubrics.count} rubrics")
      sync_rubrics(rubrics)
    end

  end

private

  def sync_rubrics(rubrics)
    rubrics.each do |rubric|
      Rails.logger.info("Syncing canvas_rubric_id=#{rubric['id']}")
      rubric_data = {
        canvas_context_id: rubric['context_id'],
        canvas_context_type: rubric['context_type'],
        canvas_rubric_id: rubric['id'],
        points_possible: rubric['points_possible'],
        title: rubric['title'],
      }
      CanvasRubric.upsert(rubric_data, unique_by: [
        :canvas_rubric_id
      ])

      Rails.logger.info("Found #{rubric['data'].length} rubric criterion")
      rubric['data'].each do |criterion|
        Rails.logger.info("Syncing canvas_criterion_id=#{criterion['id']}")
        criterion_data = {
          canvas_rubric_id: rubric['id'],
          canvas_criterion_id: criterion['id'],
          description: criterion['description'],
          long_description: criterion['long_description'],
          points: criterion['points'],
          title: criterion['title'],
        }

        CanvasRubricCriterion.upsert(criterion_data, unique_by: [
          :canvas_rubric_id, :canvas_criterion_id
        ])

        Rails.logger.info("Found #{criterion['ratings'].length} rubric ratings")
        criterion['ratings'].each do |rating|
          Rails.logger.info("Syncing canvas_rating_id=#{rating['id']}")
          rating_data = {
            canvas_rubric_id: rubric['id'],
            canvas_criterion_id: rating['criterion_id'],
            canvas_rating_id: rating['id'],
            description: rating['description'],
            long_description: rating['long_description'],
            points: rating['points'],
          }

          CanvasRubricRating.upsert(rating_data, unique_by: [
            :canvas_rubric_id, :canvas_criterion_id, :canvas_rating_id
          ])
        end
      end
    end
  end
end
