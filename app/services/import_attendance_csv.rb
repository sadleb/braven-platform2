# frozen_string_literal: true

require 'csv'

class ImportAttendanceCsv

  # Alias so we can use a shorter name.
  class CSVHeaders < AttendanceEventSubmissionsController::CSVHeaders; end

  def initialize(attendance_csv, attendance_event_submission, all_fellow_users)
    @attendance_csv = attendance_csv
    @attendance_event_submission = attendance_event_submission
    @all_fellow_users = all_fellow_users
  end

  # Return unprocessed_rows, unsaved_answers
  def run

    # Parse
    data = CSV.read(@attendance_csv.path,
                    headers: true,
                    # Normalize headers, to allow for variations in the source CSV.
                    header_converters: lambda { |h| h.parameterize.underscore },
                    encoding: 'bom|utf-8',
                    converters: lambda { |f, _| f&.strip })
      .map(&:to_h)

    # Filter
    unprocessed_rows = []
    unsaved_answers = []
    data.each do |row|
      # Add to unprocessed if "Present?" is empty or if the user is not in @fellow_users.
      user_id = row[CSVHeaders::PLATFORM_USER_ID.parameterize.underscore]&.to_i
      in_attendance = row[CSVHeaders::IN_ATTENDANCE.parameterize.underscore]
      if in_attendance.blank?
        row[AttendanceEventSubmissionsController::UNPROCESSED_REASON] = "No attendance recorded in the '#{CSVHeaders::IN_ATTENDANCE}' column"
        unprocessed_rows << row
        next
      elsif User.where(id: user_id).none?
        # Complain about invalid user IDs.
        row[AttendanceEventSubmissionsController::UNPROCESSED_REASON] = "User ID '#{user_id}' not found"
        unprocessed_rows << row
        next
      elsif @all_fellow_users.none? { |u| u.id == user_id }
        # Complain about non-enrolled Fellows.
        row[AttendanceEventSubmissionsController::UNPROCESSED_REASON] = "Not currently enrolled in this course"
        unprocessed_rows << row
        next
      end

      unsaved_answers << AttendanceEventSubmissionAnswer.new(
        attendance_event_submission: @attendance_event_submission,
        for_user_id: row[CSVHeaders::PLATFORM_USER_ID.parameterize.underscore].to_i,
        in_attendance: to_boolean(row[CSVHeaders::IN_ATTENDANCE.parameterize.underscore]),
        late: to_boolean(row[CSVHeaders::LATE.parameterize.underscore]),
        absence_reason: row[CSVHeaders::ABSENCE_REASON.parameterize.underscore]&.strip,
      )
    end

    # Warn about people missing from the CSV.
    csv_user_ids = data.map { |r| r[CSVHeaders::PLATFORM_USER_ID.parameterize.underscore].to_i }.compact
    @all_fellow_users.each do |user|
      unless csv_user_ids.include? user.id
        unprocessed_rows << {
          CSVHeaders::PLATFORM_USER_ID.parameterize.underscore => user.id,
          CSVHeaders::FIRST_NAME.parameterize.underscore => user.first_name,
          CSVHeaders::LAST_NAME.parameterize.underscore => user.last_name,
          AttendanceEventSubmissionsController::UNPROCESSED_REASON => "Enrolled in this course, but missing from CSV",
        }
      end
    end

    [unprocessed_rows, unsaved_answers]
  end

private

  # Custom string handling for CSV import values.
  # Returns true, false, or nil depending on the value.
  def to_boolean(value)
    value = value&.downcase&.strip
    return false if value == "no"
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
