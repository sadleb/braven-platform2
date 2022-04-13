# frozen_string_literal: true

require 'canvas_api'

# Canvas Assignment Overrides represent assignment due dates for different
# sections/users.
class CopyCanvasAssignmentOverrides

  class NoTranslatedOverridesError < StandardError; end

  def initialize(course, section, canvas_assignment_overrides)
    @course = course
    @section = section
    @canvas_assignment_overrides = canvas_assignment_overrides
  end

  def run
    Honeycomb.start_span(name: 'copy_canvas_assignment_overrides.run') do
      # Translate the canvas_assignment_ids from the old course to the equivalent
      # assignments in the new course, by name. Note this will remove assignments
      # that it can't find with the same name in the new course.
      new_assignments = CanvasAPI.client.get_assignments(@course.canvas_course_id)
      Honeycomb.add_field('copy_canvas_assignment_overrides.new_assignments.count', new_assignments.count)

      # note: @canvas_assignment_overrides has already been dup-shifted, so direct
      # modification is fine. It's also explicitly *not* saved to the database,
      # so don't run .save or .update here.
      translated_overrides = @canvas_assignment_overrides.filter_map do |override|
        new_assignment = new_assignments.find { |a| a['name'] == override.assignment_name }
        # Skip assignments we can't find in the new course.
        unless new_assignment
          Rails.logger.warn("Skipping canvas_assignment_id=#{override.canvas_assignment_id}, name=#{override.assignment_name}")
          next
        end

        # Translate assignment and section IDs.
        override.canvas_assignment_id = new_assignment['id']
        override.canvas_section_id = @section.canvas_section_id

        # Convert to the format expected by the Canvas API.
        override.to_canvas_hash
      end
      Honeycomb.add_field('copy_canvas_assignment_overrides.translated_overrides.count', translated_overrides.count)

      # If something went terribly wrong and we now have an empty list, the next
      # Canvas call will fail - so let's handle that more gracefully. Raise a
      # custom exception we can handle in the controller.
      if translated_overrides.empty?
        Honeycomb.add_field('copy_canvas_assignment_overrides.translated_overrides.empty?', true)
        raise NoTranslatedOverridesError.new
      end

      # Create the overrides in Canvas first, since the local db requires an
      # override_id that we get from Canvas.
      created_overrides = CanvasAPI.client.create_assignment_overrides(
        @course.canvas_course_id,
        translated_overrides
      )
      Honeycomb.add_field('copy_canvas_assignment_overrides.created_overrides.count', created_overrides.count)

      # Use the Canvas response to save the overrides in the local db.
      CanvasAssignmentOverride.transaction do
        created_overrides.each do |override|
          # Note: We say `override_hashes` because `parse_attributes` returns a
          # list, but since these are all for sections, there will only ever be
          # one override hash in the list. (See CanvasAssignmentOverride model
          # for more details.)
          # Convert from Canvas API format, back into the format we use in the
          # local DB.
          override_hashes = CanvasAssignmentOverride.parse_attributes(override, @course.canvas_course_id)
          # Modify to include assignment_name, which isn't in the data returned
          # from Canvas.
          override_hashes = override_hashes.map do |override_hash|
            new_assignment = new_assignments.find { |a| a['id'] == override_hash[:canvas_assignment_id] }
            # Use safe accessors so we fall back to nil if something's missing.
            override_hash[:assignment_name] = new_assignment&.dig('name')
            override_hash
          end

          # We're creating these right now, so no need for an upsert.
          CanvasAssignmentOverride.insert_all!(override_hashes)
        end
      end

      Honeycomb.add_field('copy_canvas_assignment_overrides.success?', true)
    end
  end
end
