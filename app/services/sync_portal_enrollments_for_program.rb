# frozen_string_literal: true
require 'salesforce_api'

# Syncs all folks from the specific Salesforce Program to Canvas.
# TODO: rename to SyncWithSalesforceProgram or SyncSalesforceProgram (since it now syncs
# more stuff than just enrollments and it's not just "from" Salesforce anymore,
# it syncs stuff back to the Program / Participants like Zoom links and signup_tokens)
class SyncPortalEnrollmentsForProgram
  include Rails.application.routes.url_helpers

  attr_reader :sf_program_id, :failed_participants, :count

  class SyncPortalEnrollmentsForProgramError < StandardError; end
  class CanvasUserIdMismatchError < StandardError; end

  FailedParticipantInfo = Struct.new(:salesforce_id, :email, :first_name, :last_name, :error_detail, keyword_init: true)

  def initialize(salesforce_program_id:, send_signup_emails: false, force_zoom_update: false)
    @sf_program_id = salesforce_program_id
    @sf_program = nil
    @send_signup_emails = send_signup_emails
    @force_zoom_update = force_zoom_update
    @failed_participants = []
  end

  def run
    Honeycomb.add_field_to_trace('salesforce.program.id', @sf_program_id)
    Honeycomb.add_field('sync_portal_enrollments_for_program.send_signup_emails', @send_signup_emails)
    Honeycomb.add_field('sync_portal_enrollments_for_program.force_zoom_update', @force_zoom_update)

    program_participants.each do |participant|
      begin
        # Note that putting the span inside the begin/rescue and letting exceptions bubble through
        # the block causes Honeycomb to automatically set the 'error' and 'error_detail' fields.
        Honeycomb.start_span(name: 'sync_portal_enrollments_for_program.sync_participant') do |span|
          span.add_field('app.sync_portal_enrollments_for_program.sync_participant_complete', false)
          span.add_field('app.salesforce.contact.id', participant.contact_id)
          span.add_field('app.salesforce.student.id', participant.student_id)
          span.add_field('app.salesforce.program.id', participant.program_id)

          # Create local users here before calling SyncPortalEnrollmentForAccount.
          # Also sends signup token to Salesforce, and emails the user a signup link.
          user = find_or_set_up_user!(participant)

          # Can happen if they were marked Dropped or Completed before having ever created their User
          next if user.blank?

          SyncZoomLinksForParticipant.new(participant, @force_zoom_update).run

          portal_user = canvas_client.find_user_by(
            email: participant.email,
            salesforce_contact_id: participant.contact_id,
            student_id: participant.student_id
          )

          if portal_user.nil?
            # Shared field with sync_portal_enrollment_for_account, hence the more generic name.
            span.add_field('app.sync_portal_enrollment.skip_reason', 'No Canvas user')
            Rails.logger.debug("no portal account yet for '#{participant.email}'; skipping")
            next
          end

          span.add_field('app.canvas.user.id', portal_user.id.to_s)

          validate_user(participant.email, user, portal_user)

          sync_portal_enrollment!(user, portal_user, participant)

          span.add_field('app.sync_portal_enrollments_for_program.sync_participant_complete', true)
        end
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
      raise SyncPortalEnrollmentsForProgramError, "Some participants failed to sync => #{@failed_participants.inspect}"
    end

    self
  end

  private

  def sync_portal_enrollment!(user, portal_user, participant)
    SyncPortalEnrollmentForAccount
      .new(user: user,
           portal_user: portal_user,
           salesforce_participant: participant,
           salesforce_program: sf_program)
      .run
  end

  def find_or_set_up_user!(sf_participant)
    user = User.find_by(salesforce_id: sf_participant.contact_id)
    Honeycomb.add_field('user.present?', user.present?)

    if user.blank?
      unless sf_participant.status == SalesforceAPI::ENROLLED
        # Shared field with sync_portal_enrollment_for_account, hence the more generic name.
        Honeycomb.add_field('sync_portal_enrollment.skip_reason', 'Not Enrolled and never synced before')
        Rails.logger.debug("No platform User and not Enrolled for '#{sf_participant.email}'; skipping")
        return user
      end

      # NOTE: This can fail if there are duplicate Contacts with the same
      # email on Salesforce. This should be prevented by Salesforce.
      user = User.new(
        salesforce_contact_params(sf_participant)
          .merge({salesforce_id: sf_participant.contact_id})
      )

      # Don't send confirmation email yet; we do that at sign_up time instead.
      #
      # Note that there are 4 scenarios where the user gets this email to confirm
      # and activate their account:
      # 1) After they get a sign_up link, create their password, and register their account
      # 2) After they use the password reset link with an account that has never been registered,
      #    and are sent to create their account instead
      # 3) After manually requesting a new confirmation email when trying to log in with
      #    valid credentials for an unconfirmed account.
      # 4) After a staff member changes their login email (from Salesforce)
      user.skip_confirmation_notification!

      # Save before token generation, just because it makes it clearer
      # if validations fail.
      user.save!

      # Generate the signup token.
      raw_signup_token = user.set_signup_token!

      # Set these new User fields on the Salesforce Contact record
      # Note: call it with the raw token, *not* the encoded one from the database b/c that's
      # what is needed in the Account Create Link.
      salesforce_contact_fields_to_set = {
        'Platform_User_ID__c': user.id,
        'Signup_Token__c': raw_signup_token,
      }
      SalesforceAPI.client.update_contact(user.salesforce_id, salesforce_contact_fields_to_set)

      if @send_signup_emails
        user.send_signup_email!(raw_signup_token)
        Honeycomb.add_field('sync_portal_enrollments_for_program.signup_email_sent', true)
      end
    end

    # Be careful to only add this to the span b/c there is not a single "user" associated
    # with this trace. We're instrumenting information about multiple users.
    user&.add_to_honeycomb_span('sync_portal_enrollments_for_program')

    user
  end

  def validate_user(email, user, canvas_user)
    unless user.canvas_user_id == canvas_user.id
      message = <<-EOF
On Canvas, the user with email #{email} has a Canvas User Id = '#{canvas_user.id}'
but it's set to '#{user.canvas_user_id}' on Platform. These must match.
Fix it here: #{user_url(user)} and in the Salesforce Contact record: #{user.salesforce_id}.
EOF
      raise CanvasUserIdMismatchError, message
    end
  end

  def translate_error_to_user_message(e, participant)
    error_detail = "#{e.class}: #{e.message}"
    if e.is_a?(ActiveRecord::RecordInvalid)
      ar_error = e.record.errors.first
      if ar_error.attribute == :email && ar_error.type == :taken
        existing_user = User.find_by_email(participant.email)
        error_detail = <<-EOF
Hmmm, there is already a Platform user with email: #{participant.email}.
We can't create a second user with that email. Are there duplicate Contacts in Salesforce?
Make sure this one is the only one: #{user_url(existing_user)}. Their Contact ID is: #{existing_user.salesforce_id}.
If that is not the issue, make sure the Platform user has the correct Salesforce Contact ID
that we're trying to sync which is: #{participant.contact_id}.
EOF
      end
    # These are rescued at a lower level and translated to a user friendly message. Just show that.
    elsif e.is_a?(CanvasUserIdMismatchError) ||
          e.is_a?(ZoomAPI::ZoomMeetingEndedError) ||
          e.is_a?(ZoomAPI::BadZoomRegistrantFieldError)
      error_detail = e.message
    end
    error_detail
  end

  # The new user params where Salesforce is the source of truth
  def salesforce_contact_params(sf_participant)
    {
      email: sf_participant.email,
      first_name: sf_participant.first_name,
      last_name: sf_participant.last_name,
    }
  end

  def program_participants
    # TODO: store the last time this was run for this course and in subsequent calls, pass that
    # in to the final SalesforceAPI.get_participants() method as the last_modified_since parameter
    # so that we only process modified ones and don't hit the CanvasAPI like crazy
    participants = sf_client.find_participants_by(program_id: sf_program.id)
    @count = participants.count || 0
    participants
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
