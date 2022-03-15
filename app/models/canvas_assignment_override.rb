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

  # Parse the hash created from the CanvasAPI json response into a list
  # of hashes matching the attributes for this model. 
  def self.parse_attributes(override, canvas_course_id)
    data = {
      canvas_course_id: canvas_course_id,
      canvas_assignment_override_id: override['id'],
      canvas_assignment_id: override['assignment_id'],
      canvas_section_id: override['course_section_id'],
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
