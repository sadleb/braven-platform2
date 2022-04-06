# frozen_string_literal: true
require 'canvas_api'

# Service to create a Section both locally and in Canvas.
# This should only be run if the Section does not already
# exist.
class CreateSection

  def initialize(course, section_name, section_type, salesforce_id=nil)
    @course = course
    @section_name = section_name
    @section_type = section_type
    @salesforce_id = salesforce_id
  end

  def run
    local_section = nil
    Honeycomb.start_span(name: 'create_section.run') do
      Honeycomb.add_field('create_section.success?', false)
      Honeycomb.add_field('canvas.course.id', @course.canvas_course_id.to_s)
      Honeycomb.add_field('section.course_id', @course.id.to_s)
      Honeycomb.add_field('section.name', @section_name)
      Honeycomb.add_field('section.salesforce_id', @salesforce_id)
      Honeycomb.add_field('section.section_type', @section_type)

      validate_arguments

      local_section = Section.create!(
        course: @course,
        salesforce_id: @salesforce_id,
        name: @section_name,
        section_type: @section_type
      )
      local_section.add_to_honeycomb_span()

      canvas_section = create_canvas_section(local_section)

      begin
        local_section.update!(canvas_section_id: canvas_section['id'])
      rescue => e
        msg = "A new Canvas section with canvas_section_id=#{canvas_section['id']} was created but we " +
              "failed to set it on the local Platform section with id=#{local_section.id}. " +
              "The sync will continue failing to enroll folks in this section until this is fixed manually.\n" +
              "Error: #{e.inspect}"
        Honeycomb.add_alert('set_canvas_section_id_failed', msg)
        Rails.logger.error(msg)
        raise
      end


      Honeycomb.add_field('create_section.success?', true)
    end

    local_section
  end

private

  def create_canvas_section(local_section)
    canvas_section = CanvasAPI.client.create_section(
      @course.canvas_course_id,
      local_section.name,
      local_section.sis_id
    )
    Honeycomb.add_field('section.canvas_section_id', canvas_section['id'].to_s)
    canvas_section
  rescue
    local_section.destroy
    raise
  end

  def validate_arguments
    if @salesforce_id.nil?
      # There can only be a single one of these per course. They don't have an associated
      # salesforce_id in order uniquely identify them.
      return if (
        @section_type == Section::Type::TEACHING_ASSISTANTS ||
        @section_type == Section::Type::DEFAULT_SECTION
      )

      raise ArgumentError, "missing salesforce_id for section_type=#{@section_type}"
    end
  end
end
