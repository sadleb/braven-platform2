# frozen_string_literal: true

class CanvasAssignmentOverride < ApplicationRecord
  # Note we can NOT use canvas_assignment_override_id as a PK here, because
  # it's not unique in this table. See the
  # index_canvas_assignment_overrides_unique_1 index for details on how we
  # check uniqueness in this table. We also can't use a multi-column
  # PK because two of the columns we'd want to use are nullable. That means
  # we're using the standard autoincrement ID (canvas_assignment_override.id),
  # so watch out for ambiguous code that confuses that local ID with the remote
  # canvas_assignment_override.canvas_assignment_override_id.

  belongs_to :course, primary_key: :canvas_course_id, foreign_key: :canvas_course_id

  belongs_to :section, primary_key: :canvas_section_id, foreign_key: :canvas_section_id, optional: true
  belongs_to :user, primary_key: :canvas_user_id, foreign_key: :canvas_user_id, optional: true
  alias_attribute :student, :user

  # Assignment types
  [
    :course_attendance_event,
    :course_custom_content_version,
    :course_rise360_module_version,
  ].each do |name|
    belongs_to name, primary_key: :canvas_assignment_id, foreign_key: :canvas_assignment_id, optional: true
  end

  # Dynamically return the referenced assignment, if it's one that's
  # represented in our database. This is just a convenience method.
  def assignment
    course_attendance_event&.attendance_event ||
      course_custom_content_version&.custom_content_version&.custom_content ||
      course_rise360_module_version&.rise360_module_version&.rise360_module
  end

  # Return a hash in the format expected by Canvas.
  # Only for use with section overrides, not user-level overrides.
  # See also lib/canvas_api.rb:create_assignment_overrides.
  def to_canvas_hash
    raise RuntimeError, "to_canvas_hash() can't be run on overrides with no section id" unless canvas_section_id

    {
      assignment_id: canvas_assignment_id.to_i,
      course_section_id: canvas_section_id.to_i,
      due_at: due_at&.iso8601,
      all_day: all_day,
      all_day_date: all_day_date&.iso8601,
      unlock_at: unlock_at&.iso8601,
      lock_at: lock_at&.iso8601,
    }
  end

  # Parse the hash created from the CanvasAPI json response into a list
  # of hashes matching the attributes for this model. 
  def self.parse_attributes(override, canvas_course_id)
    data = {
      canvas_course_id: canvas_course_id,
      canvas_assignment_override_id: override['id'],
      canvas_assignment_id: override['assignment_id'],
      canvas_section_id: override['course_section_id'],
      assignment_name: override['assignment_name'],
      title: override['title'],
      due_at: override['due_at'],
      all_day: override['all_day'],
      all_day_date: override['all_day_date'],
      unlock_at: override['unlock_at'],
      lock_at: override['lock_at'],
    }

    if override['student_ids']
      # If the AssignmentOverride has student_ids, we create one
      # CanvasAssignmentOverride for each student, so we can use this data in
      # Periscope without having to parse serialized data there.
      override['student_ids'].map do |student_id|
        student_data = data.dup
        student_data[:canvas_user_id] = student_id
        student_data
      end
    else
      # Otherwise, this AssignmentOverride is for a section, and we'll only
      # return one. Still return it in a list, for easier handling by callers.
      [data]
    end
  end
end
