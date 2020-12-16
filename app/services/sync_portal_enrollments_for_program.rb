# frozen_string_literal: true

# Syncs all folks from the specific Salesforce Program to Canvas.
class SyncPortalEnrollmentsForProgram
  def initialize(salesforce_program_id:)
    @sf_program_id = salesforce_program_id
    @sf_program = nil
  end

  def run
    program_participants.each do |participant|
      portal_user = canvas_client.find_user_by(
        email: participant.email,
        salesforce_contact_id: participant.contact_id,
        student_id: participant.student_id
      )
      if portal_user.nil?
        Rails.logger.debug("no portal account yet for '#{participant.email}'; skipping")
        next
      end

      reconcile_email!(portal_user, participant) if email_inconsistent?(portal_user, participant)
      sync_portal_enrollment!(portal_user, participant)
    end
  end

  private

  attr_reader :sf_program_id

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

  def program_participants
    # TODO: store the last time this was run for this course and in subsequent calls, pass that
    # in to the final SalesforceAPI.get_participants() method as the last_modified_since parameter
    # so that we only process modified ones and don't hit the CanvasAPI like crazy
    sf_client.find_participants_by(program_id: sf_program.id)
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
