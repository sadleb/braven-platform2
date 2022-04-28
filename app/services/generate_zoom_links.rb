# frozen_string_literal: true
require 'csv'
require 'zoom_api'

class GenerateZoomLinks
  attr_reader :failed_participants

  class GenerateZoomLinksError < StandardError; end

  class ZoomAccountType
    LICENSED=2
    ON_PREM=3
  end

  class ZoomMeetingType
    RECURRING=8
    SCHEDULED=2
  end

  class ZoomApprovalType
    NO_REGISTRATION_REQUIRED=2
  end

  # @param [Array] participants: each item in the array is a hash with:
  #   { email: 'some-email@email.some', first_name: 'some-name', last_name: 'some-name'}
  def initialize(meeting_id:, participants_file_path:, email:, participants: nil)
    @meeting_id = meeting_id.delete_whitespace
    @participants_file_path = participants_file_path
    @email = email
    @participants_to_register = participants
    @failed_participants = []
  end

  def validate_and_run
    meeting_info = validate_meeting(@meeting_id)
    check_meeting_settings(meeting_info)
    check_csv_headers(participants_to_register(meeting_info['host_email']).first.keys)
    GenerateZoomLinksJob.perform_later(@meeting_id, @participants_file_path, @email, participants_to_register)
  end

  def run
    Honeycomb.add_field('generate_zoom_links.participants', participants_to_register)
    Honeycomb.add_field('generate_zoom_links.participants.count', participants_to_register.count)

    registered_participants = add_registered_participants_to_meeting()

    unless @failed_participants.empty?
      Rails.logger.error(@failed_participants.inspect)
      msg = "Failed to generate Zoom links. The following participants failed => #{@failed_participants.inspect}"
      Honeycomb.add_alert('generate_zoom_links.failed_participants', msg)
      raise GenerateZoomLinksError, msg
    end

    # Generate a CSV populated with the join_url so we can email it
    CSV.generate do |csv|
      csv << ['email', 'first_name', 'last_name', 'join_url']
      registered_participants.each { |participant| csv << participant.values }
    end
  end

private
  # Return particpants to register if present otherwise parse the CSV file
  def participants_to_register(meeting_host_email=nil)
    return @participants_to_register if @participants_to_register

    # There are two possible encodings for .csv files (well 3 if you count the Windows one).
    # The following encoding appears to work for both Mac versions. I empirically tested this
    # by using Save As: "CSV UTF-8" as well as the plain "CSV" formats with Excel v16.49 on a Mac
    # This article helped me find the fix:
    # https://jamescrisp.org/2020/05/05/importing-excel-365-csvs-with-ruby-on-osx/
    #
    # Also, the "validation_converter" handles stripping/trimming whitespace since it's common for folks
    # to copy/paste a value and end up with a trailing space and validates row-level issues.
    validation_converter = ->(field, field_info) {
      columns = ['first', 'second', 'third']

      # Validating CSV cells and headers here because the validation converter loops through all the cells
      # and will throw an error if any are blank so handling it here to raise the errors we want. Also
      # checking the headers here because if there is an extra header, it will throw an error saying one
      # of the cells are blank here if it is left empty under a header (even if the header should not be there).
      if field_info.index > 2
        raise GenerateZoomLinksError, "You have too many columns in your CSV file, you should have 3 (email, first_name, last_name) and you have #{field_info.index + 1}."
      elsif field_info.header.blank?
        raise GenerateZoomLinksError, "You have an empty header in your CSV file. You left the header in the #{columns[field_info.index]} column blank."
      elsif field.blank?
        raise GenerateZoomLinksError, "You have an empty cell in your CSV file. You left the cell in row #{field_info.line} under the #{field_info.header} header blank."
      elsif field.strip.downcase == meeting_host_email.strip.downcase
        raise GenerateZoomLinksError, "You are trying to register the host of the meeting, this cannot be done. Please remove the email '#{field}' (in row #{field_info.line}) from your CSV and try again."
      elsif field_info.index == 0 && !Devise.email_regexp.match?(field.strip)
        raise GenerateZoomLinksError, "The email '#{field}' (in row #{field_info.line}) is an invalid email address. Check that your .csv file has columns ordered correctly (email, first_name, last_name)."
      end

      field.strip
    }

    begin
      participants = CSV.read(@participants_file_path,
                          headers: true,
                          encoding:'bom|utf-8',
                          converters: validation_converter)
                    .map(&:to_h)
    rescue CSV::MalformedCSVError
      raise GenerateZoomLinksError,'Make sure the file you uploaded is saved as a CSV file (.csv).'
    end
    @participants_to_register = participants
  end

  def add_registered_participants_to_meeting()
    Rails.logger.info('Started adding participants')

    participants_to_register.map.with_index do |participant, i|
      csv_row_with_link = nil
      begin
        # using participant.values[num] instead of participant['email'], participant['first_name'],
        # participant['last_name'] because the CSV headers the user entered might not match 'email',
        # 'first_name', 'last_name' exactly
        response = ZoomAPI.client.add_registrant(
          @meeting_id,
          participant.values[0],
          participant.values[1],
          participant.values[2]
        )
        csv_row_with_link = participant.merge({ 'join_url' => response['join_url'] })
      rescue => e
        Sentry.capture_exception(e)
        # Add 2 to get the .csv row # b/c we don't parse the header row and need to make it 1 based instead of 0 based.
        row = i+2
        @failed_participants << participant.merge({'row_number' => row, 'error_detail' => "#{e.class}: #{e.message}" })
      end
      csv_row_with_link
    end.compact
  end

  def validate_meeting(meeting_id)
    begin
      Integer(meeting_id)
      meeting_info = ZoomAPI.client.get_meeting_info(meeting_id)
    rescue ArgumentError
      raise GenerateZoomLinksError,"Meeting ID '#{meeting_id}' format is invalid. It should be all numbers. Make sure you have the correct meeting ID."
    rescue ZoomAPI::ZoomMeetingDoesNotExistError,
            ZoomAPI::ZoomMeetingEndedError
      raise GenerateZoomLinksError,'This meeting was not found or has ended. Make sure you have the correct meeting ID for a meeting in the future.'
    end
    meeting_info
  end

  def check_meeting_settings(meeting_info)
    if meeting_info['type'] == ZoomMeetingType::RECURRING
      # meeting occurrences shows upcoming occurrences, so if there aren't any upcoming the meeting has ended
      meetings_array = meeting_info['occurrences']
      if meetings_array.length == 0
        raise GenerateZoomLinksError,'This meeting was not found or has ended. Make sure you have the correct meeting ID for a meeting in the future.'
      end
    elsif meeting_info['type'] != ZoomMeetingType::SCHEDULED
      raise GenerateZoomLinksError,'Only recurring Zoom meetings with a fixed time and scheduled Zoom meetings are supported.'
    end

    # Zoom host must be licensed (type 2) or on-prem (type 3)
    # https://marketplace.zoom.us/docs/api-reference/zoom-api/users/user
    host_zoom_account = ZoomAPI.client.get_zoom_user(meeting_info['host_id'])
    if host_zoom_account['type'] != ZoomAccountType::LICENSED && host_zoom_account['type'] != ZoomAccountType::ON_PREM
      raise GenerateZoomLinksError,'The meeting host does not have a licensed Zoom acount, please try again with a host that has a licensed account.'
    end

    # Registration should be set to required
    if meeting_info['settings']['approval_type'] == ZoomApprovalType::NO_REGISTRATION_REQUIRED
      raise GenerateZoomLinksError,'Registration must be set to required in the Zoom meeting settings.'
    end

    # Sending confirmation emails should be set to false
    if meeting_info['settings']['registrants_confirmation_email'] == true
      raise GenerateZoomLinksError,'Email notifications in the Zoom meeting settings must be turned off. In your meeting settings go to "Email Settings", select edit for "Confirmation Email to Registrants" and uncheck the box that says "Send Confirmation Email to Registrants". Then click save.'
    end

    # Meeting_authentication should be set to false
    if meeting_info['settings']['meeting_authentication'] == true
      raise GenerateZoomLinksError, '"Require authentication to join" must be turned off. In your Zoom meeting settings make sure this box is not checked.'
    end
  end

  # Checks the CSV headers for email, first_name, last_name in that order
  def check_csv_headers(csv_headers)
    regex_header_validation(/email/i, csv_headers[0], 'first', 'email')
    regex_header_validation(/first.*name/i, csv_headers[1], 'second', 'first_name')
    regex_header_validation(/last.*name/i, csv_headers[2], 'third', 'last_name')
  end

  def regex_header_validation(regex, user_header_field, col, header)
    unless regex.match?(user_header_field)
      raise GenerateZoomLinksError, "Your CSV file should have the headers 'email', 'first_name' and 'last_name' in that order. You have the header '#{user_header_field}' in the #{col} column instead of '#{header}'."
    end
  end
end
