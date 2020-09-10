# frozen_string_literal: true

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
        # log skip no account yet
        next
      end

      reconcile_email! if email_inconsistent?

      SyncPortalEnrollmentForAccount
        .new(portal_user: portal_user,
             salesforce_participant: participant,
             salesforce_program: sf_program)
        .run
    end
  end

  private

  attr_reader :sf_program_id

  def email_inconsistent?
    !portal_user.email.eql?(sf_participant.email)
  end

  def reconcile_email!
    ReconcileUserEmail.new(salesforce_participant: sf_participant,
                           portal_user: portal_user)
                      .run
  end

  def program_participants
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
