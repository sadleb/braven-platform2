# frozen_string_literal: true

require 'csv'

class ExportAttendanceCsv

  def initialize(course, all_fellow_users, answers)
    @course = course
    @all_fellow_users = all_fellow_users
    @answers = answers
  end

  # Return CSV object.
  def run
    export_data = CSV.generate(headers: true) do |csv|
      csv << AttendanceEventSubmissionsController::CSVHeaders::ALL_HEADERS

      # Sort by cohort, then last name, then loop over each.
      # Note in order to sort_by with an array like this, there can't be any
      # values inside the array that are unsortable (e.g. nil, true, false).
      # That's what the `cohort || ''` part's doing, is changing nil to an
      # empty string so it can be sorted appropriately.
      @all_fellow_users.sort_by { |u| [u.cohort(@course)&.name || '', u.last_name] }.each do |user|
        answer = @answers.find_by(for_user: user)

        # Make sure these match the order defined in the CSV headers!
        csv << [
          user.first_name,
          user.last_name,
          answer&.in_attendance,
          answer&.late,
          answer&.absence_reason,
          user.cohort_schedule(@course)&.name,
          user.cohort(@course)&.name,
          user.id,
        ]
      end
    end
  end
end
