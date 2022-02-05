# frozen_string_literal: true
require 'salesforce_api'
require 'canvas_api'

# Syncs all Participants from the specified Salesforce Program across
# all applications like Platform and Canvas and Zoom.
#
# Note: Discord is separate b/c it's a bot.
class SyncSalesforceProgram
  include Rails.application.routes.url_helpers

  attr_reader :sf_program_id, :failed_participants, :count

  class SyncSalesforceProgramError < StandardError; end
  class CanvasUserIdMismatchError < StandardError; end

  FailedParticipantInfo = Struct.new(:salesforce_id, :email, :first_name, :last_name, :error_detail, keyword_init: true)

  def initialize(salesforce_program_id:, force_zoom_update: false)
    @sf_program_id = salesforce_program_id
    @sf_program = nil
    @force_zoom_update = force_zoom_update
    @failed_participants = []
  end

  def run
    Honeycomb.add_field_to_trace('salesforce.program.id', @sf_program_id)
    Honeycomb.add_field('sync_salesforce_program.force_zoom_update', @force_zoom_update)

    # If you try running a sync in an environment that doesn't have the corresponding local course(s),
    # this is a NOOP. This is mostly in place to prevent developers from accidentally sync'ing another
    # dev's test program which would invalidate the signup tokens and other stuff.
    if courses_for_program.blank?
      Honeycomb.add_field('alert.sync_salesforce_program.missing_courses', sf_program.inspect)
      raise SyncSalesforceProgramError, "Missing Course models for Salesforce Program: #{sf_program.inspect}"
    end

    sync_program_id()

    program_participants.each do |participant|
      begin
        SyncSalesforceParticipant.new(participant, sf_program, @force_zoom_update).run
      rescue => e
        Sentry.capture_exception(e)
        error_detail = translate_error_to_user_message(e, participant)
        Honeycomb.add_field('error', e.class.name)
        Honeycomb.add_field('error_detail', error_detail)
        @failed_participants << FailedParticipantInfo.new(
          salesforce_id: participant.contact_id,
          email: participant.email,
          first_name: participant.first_name,
          last_name: participant.last_name,
          error_detail: error_detail
        )
      end
    end

    unless failed_participants.empty?
      Rails.logger.error(failed_participants.inspect)
      raise SyncSalesforceProgramError, "Some participants failed to sync => #{@failed_participants.inspect}"
    end

    self
  end

  private

  # When developing or QA'ing we sometimes change which Courses a given Program is configured for.
  # This updates the local database to match Salesforce for this Program.
  def sync_program_id
    return unless courses_for_program.any? { |c| c.salesforce_program_id != sf_program.id }

    # This should be uncommon enough in prod Salesforce that an alert is worthwhile so we
    # can keep an eye on it b/c if the IDs change for an actual launched Program and not a test/QA one
    # that's not good.
    Honeycomb.add_field('alert.mismatched_salesforce_program.id', sf_program.id)

    # Clear out the courses currently mapped to this salesforce_program_id so we can map the new ones
    old_courses = Course.where(salesforce_program_id: sf_program.id)
    old_courses.update_all(salesforce_program_id: nil)
    Honeycomb.add_field('mismatched_salesforce_program.old_courses', old_courses.inspect)

    courses_for_program.update_all(salesforce_program_id: sf_program.id)
    Honeycomb.add_field('mismatched_salesforce_program.new_courses', courses_for_program.inspect)
  end

  def translate_error_to_user_message(e, participant)
    error_detail = "#{e.class}: #{e.message}"
    if e.is_a?(ActiveRecord::RecordInvalid)
      ar_error = e.record.errors.first
      if ar_error.attribute == :email && ar_error.type == :taken
        existing_user = User.find_by_email(participant.email)
        error_detail = <<-EOF
It looks like there are duplicate Contacts in Salesforce with the email: #{participant.email}. Open the Contact with ID: #{existing_user.salesforce_id} and use the "Duplicate Check -> Merge" tool to get rid of the duplicate. Make sure and choose #{existing_user.salesforce_id} as the Master record!

For reference, the existing Platform user is: #{user_url(existing_user)} and the duplicate Contact ID is: #{participant.contact_id}.
EOF
      end
    # These are rescued at a lower level and translated to a user friendly message. Just show that.
    elsif e.is_a?(CanvasUserIdMismatchError) ||
          e.is_a?(ZoomAPI::ZoomMeetingEndedError) ||
          e.is_a?(ZoomAPI::RegistrationNotEnabledForZoomMeetingError) ||
          e.is_a?(ZoomAPI::ZoomMeetingDoesNotExistError) ||
          e.is_a?(ZoomAPI::TooManyRequestsError) ||
          e.is_a?(ZoomAPI::BadZoomRegistrantFieldError)
      error_detail = e.message
    elsif e.is_a?(CanvasAPI::TimeoutError)
      error_detail = e.message << " Until it works this user may have trouble accessing Canvas: #{participant.email}"
    end
    error_detail
  end

  def program_participants
    # TODO: store the last time this was run for this course and in subsequent calls, pass that
    # in to the final SalesforceAPI.get_participants() method as the last_modified_since parameter
    # so that we only process modified ones and don't hit the CanvasAPI like crazy
    participants = sf_client.find_participants_by(program_id: sf_program.id)
    @count = participants.count || 0
    participants
  end

  def courses_for_program
    @courses_for_program ||= Course.where(canvas_course_id: [sf_program.fellow_course_id, sf_program.leadership_coach_course_id])
  end

  def sf_program
    @sf_program ||= sf_client.find_program(id: sf_program_id)
  end

  def sf_client
    SalesforceAPI.client
  end

  def canvas_client
    CanvasAPI.client
  end
end
