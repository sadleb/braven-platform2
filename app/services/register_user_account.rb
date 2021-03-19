# frozen_string_literal: true

# Fully registers and creates a new User account in all of our systems
# (aka Platform, Canvas and Salesforce) so that it's ready for use.
# Everything must be consistent and in sync so the systems can work together.
class RegisterUserAccount
  RegisterUserAccountError = Class.new(StandardError)

  def initialize(sign_up_params)
    # We want Salesforce to be the source of truth, especially for their email, to avoid
    # duplicating user accounts. When they register their user account, we just 
    # collect their salesforce ID and password and look up the rest of the info
    # they gave us when they signed up / applied.
    @salesforce_participant = sf_client.find_participant(contact_id: sign_up_params[:salesforce_id])
    @salesforce_program = sf_client.find_program(id: @salesforce_participant.program_id)
    @create_user_params = sign_up_params.merge(salesforce_contact_params)
  end

  def run
    Honeycomb.start_span(name: 'RegisterUserAccount.run') do |span|
      span.add_field('app.salesforce.contact.id', @salesforce_participant.contact_id)

      # Need to have the User record saved before the Canvas sync runs since it relies on it.
      # Essentially do an upsert
      @new_user = User.find_or_create_by(
        salesforce_id: @create_user_params[:salesforce_id]
      )
      @new_user.update(@create_user_params)
      # Allow error handling on model validation when called from a controller.
      yield @new_user if block_given?
      span.add_field('app.user.id', @new_user.id)

      # Create a user in Canvas.
      create_canvas_user!
      span.add_field('app.canvas.user.id', @new_user.canvas_user_id)

      canvas_user_id_set = sf_client.set_canvas_user_id(
                                     @salesforce_participant.contact_id,
                                     @new_user.canvas_user_id)
      span.add_field('app.register_user_account.salesforce_canvas_user_id_set', true)

      # If this fails, there is nothing to rollback. We just need to retry it and/or
      # fix the bug after finding out that they can't see the proper course content.
      sync_canvas_enrollment!
      span.add_field('app.register_user_account.canvas_enrollment_synced', true)
    end

    # Note: we actually don't want to roll anything back if there are failures. We wouldn't
    # want to accidentailly delete a Canvas user and their work, or a Platform user and their
    # work. Instead, we're adding fields to the Honeycomb span to more easily diagnose and
    # troubleshoot the issues. As things arise, we should enhance this code to be re-runnable
    # so that if it fails you just have to try again and it will work if the underlying issue
    # is fixed.
  end

private

  def sync_canvas_enrollment!
    # TODO: rename Portal to Canvas everywhere.
    SyncPortalEnrollmentForAccount
      .new(portal_user: CanvasAPI::LMSUser.new(@new_user.canvas_user_id),
           salesforce_participant: @salesforce_participant,
           salesforce_program: @salesforce_program)
      .run
  end

  def create_canvas_user!
    unless salesforce_participant_enrolled?
      raise RegisterUserAccountError, "Salesforce Contact ID not enrolled: #{@new_user.salesforce_id}"
    end

    canvas_user = CanvasAPI.client.create_user(
      @salesforce_participant.first_name,
      @salesforce_participant.last_name,
      @salesforce_participant.email,  # username
      @salesforce_participant.email,
      @salesforce_participant.contact_id,
      @salesforce_participant.student_id,
      @salesforce_program.timezone
    )
    @new_user.update!(canvas_user_id: canvas_user['id'])
  end

  # The new user params where Salesforce is the source of truth
  def salesforce_contact_params
    {
      email: @salesforce_participant.email,
      first_name: @salesforce_participant.first_name,
      last_name: @salesforce_participant.last_name,
    }
  end

  def salesforce_participant_enrolled?
    @salesforce_participant.status.eql?(SalesforceAPI::ENROLLED)
  end

  def sf_client
    @sf_client ||= SalesforceAPI.client
  end

end
