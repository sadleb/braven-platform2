# frozen_string_literal: true

# Syncs all folks from the specific Salesforce Program to Canvas.
class SyncPortalEnrollmentsForProgram
  attr_reader :sf_program_id, :failed_participants, :count

  class SyncPortalEnrollmentsForProgramError < StandardError; end

  FailedParticipantInfo = Struct.new(:salesforce_id, :email, :first_name, :last_name, :error_detail, keyword_init: true)

  def initialize(salesforce_program_id:)
    @sf_program_id = salesforce_program_id
    @sf_program = nil
    @failed_participants = []
  end

  def run
    program_participants.each do |participant|
      begin
        # Note that putting the span inside the begin/rescue and letting exceptions bubble through
        # the block causes Honeycomb to automatically set the 'error' and 'error_detail' fields.
        Honeycomb.start_span(name: 'sync_portal_enrollments_for_program.sync_participant') do |span|
          span.add_field('app.sync_portal_enrollments_for_program.sync_participant_complete', false)
          span.add_field('app.user.email', participant.email)
          span.add_field('app.salesforce.contact.id', participant.contact_id)
          span.add_field('app.salesforce.student.id', participant.student_id)

          # Create local users here before calling SyncPortalEnrollmentForAccount.
          user = find_or_create_user!(participant)
          span.add_field('app.user.id', user.id)
          span.add_field('app.user.confirmed?', user.confirmed?)
          span.add_field('app.user.registered?', user.registered?)

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

          span.add_field('app.canvas.user.id', portal_user.id)

          reconcile_email!(portal_user, participant) if email_inconsistent?(portal_user, participant)
          sync_portal_enrollment!(portal_user, participant)

          span.add_field('app.sync_portal_enrollments_for_program.sync_participant_complete', true)
        end
      rescue => e
        Sentry.capture_exception(e)
        @failed_participants << FailedParticipantInfo.new(
          salesforce_id: participant.contact_id,
          email: participant.email,
          first_name: participant.first_name,
          last_name: participant.last_name,
          error_detail: "#{e.class}: #{e.message}"
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

  def email_inconsistent?(portal_user, participant)
    !participant.email.casecmp(portal_user.email).zero?
  end

  def reconcile_email!(portal_user, participant)
    ReconcileUserEmail.new(salesforce_participant: participant,
                           portal_user: portal_user)
                      .run
  end

  def sync_portal_enrollment!(portal_user, participant)
    SyncPortalEnrollmentForAccount
      .new(portal_user: portal_user,
           salesforce_participant: participant,
           salesforce_program: sf_program)
      .run
  end

  def find_or_create_user!(sf_participant)
    user = User.find_by(salesforce_id: sf_participant.contact_id)

    unless user.present?
      # NOTE: This can fail if there are duplicate Contacts with the same
      # email on Salesforce. This should be prevented by Salesforce.
      user = User.new(
        salesforce_contact_params(sf_participant)
          .merge({salesforce_id: sf_participant.contact_id})
      )
      # Don't send confirmation email yet; we do that at sign_up time instead.
      user.skip_confirmation_notification!
      user.save!
    end

    user
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
