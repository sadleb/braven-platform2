# frozen_string_literal: true

require 'canvas_api'
require 'salesforce_api'

# Canvas Assignment Overrides represent assignment due dates for different
# sections/users.
class SyncCanvasAssignmentOverrides
  def run
    Honeycomb.start_span(name: 'sync_canvas_assignment_overrides.run') do
      canvas_course_ids = HerokuConnect::Program.current_and_future_accelerator_canvas_course_ids
      Honeycomb.add_field('sync_canvas_assignment_overrides.courses.count', canvas_course_ids.count)
      Rails.logger.info("Found #{canvas_course_ids.count} courses")

      canvas_course_ids.each do |canvas_course_id|
        SyncCanvasAssignmentOverrides.sync_course(canvas_course_id)
      end
    end
  end

  def self.sync_course(canvas_course_id)
    Honeycomb.start_span(name: 'sync_canvas_assignment_overrides.course') do
      Honeycomb.add_field('canvas.course.id', canvas_course_id.to_s)
      Rails.logger.info("Syncing assignment overrides for canvas_course_id=#{canvas_course_id}")

      # Note: We're assuming here that the assignment-level due/lock/unlock dates
      # are not set, and that all dates are configured via section or user-level
      # overrides. If that ends up not being true, we'll have to change some of
      # this to account for that.
      overrides = CanvasAPI.client.get_assignment_overrides_for_course(canvas_course_id)
      Honeycomb.add_field('sync_canvas_assignment_overrides.overrides.count', overrides.count)

      overrides.each do |override|
        Honeycomb.start_span(name: 'sync_canvas_assignment_overrides.override') do
          Honeycomb.add_field('canvas.assignment.id', override['assignment_id'].to_s)
          Honeycomb.add_field('canvas.override.id', override['id'].to_s)
          Honeycomb.add_field('canvas.override.title', override['title'])
          Rails.logger.info("Syncing override #{override['id']} for assignment #{override['assignment_id']}")

          override_hashes = CanvasAssignmentOverride.parse_attributes(override, canvas_course_id)

          # See the referenced unique constraint for details on how we're
          # checking uniqueness here.
          CanvasAssignmentOverride.upsert_all(override_hashes, unique_by:
            [:index_canvas_assignment_overrides_unique_1])
        end
      end
    end
  end
end
