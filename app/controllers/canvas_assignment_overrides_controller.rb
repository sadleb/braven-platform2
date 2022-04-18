# frozen_string_literal: true

class CanvasAssignmentOverridesController < ApplicationController
  include DryCrud::Controllers::Nestable
  nested_resource_of Course

  layout 'admin'

  # Be sure to update this if we change the assignment name elsewhere.
  ANCHOR_ASSIGNMENT = 'ATTEND: Learning Lab 1: Onboard To Braven'

  before_action :set_from_course, only: [:preview, :bulk_create]
  before_action :set_from_section, only: [:preview, :bulk_create]
  before_action :set_to_section, only: [:preview, :bulk_create]
  before_action :set_offset, only: [:preview, :bulk_create]
  before_action :set_shifted_canvas_assignment_overrides, only: [:preview, :bulk_create]

  def index
    authorize CanvasAssignmentOverride
  end

  def copy_from_course
    authorize CanvasAssignmentOverride, :new?

    # Modify as-needed to adjust what shows up in the course dropdown.
    @courses = Course.where.not(canvas_course_id: nil).order(created_at: :desc)
    # TODO: Default to last year's course for this same region/season, where possible.

    # Note: this is a possible future target for refactoring.
    # If this map of sections gets unreasonably large, it would be better to
    # provide a JSON api and fetch the list of sections via AJAX.
    @sections_by_course = @courses.map { |c| [c.id, c.sections.cohort_schedule.pluck(:name, :canvas_section_id)] }.to_h
    @to_sections = @course.sections.cohort_schedule
    @anchor_assignment = ANCHOR_ASSIGNMENT
  end

  def preview
    authorize CanvasAssignmentOverride, :new?
  end

  def bulk_create
    authorize CanvasAssignmentOverride, :create?

    begin
      service = CopyCanvasAssignmentOverrides.new(@course, @to_section, @shifted_canvas_assignment_overrides)
      service.run

    # Handle any exceptions from the service that we want to show to the end user.
    rescue CopyCanvasAssignmentOverrides::NoTranslatedOverridesError
      return redirect_to copy_from_course_course_canvas_assignment_overrides_path(course_id: @course.id),
        alert: 'Failed to copy assignment dates! Unable to find matching assignment names in the new course.'
    end

    redirect_to copy_from_course_course_canvas_assignment_overrides_path(course: @course),
      notice: 'Assignment dates successfully copied!'
  end

private

  def set_from_course
    @from_course = Course.find(params[:from_course])
  end

  def set_from_section
    @from_section = Section.find_by!(canvas_section_id: params[:from_section])
  end

  def set_to_section
    @to_section = Section.find_by!(canvas_section_id: params[:to_section])
  end

  def set_offset
    @offset = params[:date_offset].to_i
  end

  # Shift and return new copies of the overrides, without saving anything to the db.
  def set_shifted_canvas_assignment_overrides
    @shifted_canvas_assignment_overrides = CanvasAssignmentOverride
      .where(course: @from_course, section: @from_section)
      .order(:due_at, :assignment_name)
      .map do |override|
        shifted_override = override.dup
        shifted_override.due_at = override.due_at + @offset.days if override.due_at
        shifted_override.unlock_at = override.unlock_at + @offset.days if override.unlock_at
        shifted_override.lock_at = override.lock_at + @offset.days if override.lock_at

        shifted_override
      end
  end
end
