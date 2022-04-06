# frozen_string_literal: true

# "Registers" the local Platform User, which basically means that
# the account now has a password. We also refer to this as "Sign Up"
class RegisterUserAccount
  RegisterUserAccountError = Class.new(StandardError)

  # The params should include `password`, `password_confirmation`, and *either*
  # `signup_token` OR `reset_password_token`.
  def initialize(user, sign_up_params)
    @user = user
    # Keep a reference to the params so we know which token(s) to check for expiry.
    # Note the tokens may be expired here, we don't check that until later.
    @sign_up_params = sign_up_params
  end

  def run
    Honeycomb.start_span(name: 'register_user_account.run') do |span|

      # Mimic Devise's reset_password_by_token behavior for expired tokens.
      # https://github.com/heartcombo/devise/blob/57d1a1d3816901e9f2cc26e36c3ef70547a91034/lib/devise/models/recoverable.rb#L145
      # Note if someone tries to use both tokens at once (why??) and one is expired but
      # the other isn't, we act the same as if both were expired. Because that's easier.
      if @sign_up_params[:signup_token].present? && !@user.signup_period_valid?
        span.add_field('app.register_user.signup_token_expired', true)
        @user.errors.add(:signup_token, :expired)
        yield @user if block_given?
        return
      end
      if @sign_up_params[:reset_password_token].present? && !@user.reset_password_period_valid?
        span.add_field('app.register_user.reset_password_token_expired', true)
        @user.errors.add(:reset_password_token, :expired)
        yield @user if block_given?
        return
      end

      sync_contact_service = SyncSalesforceContact.new(@user.salesforce_id)
      @salesforce_contact = sync_contact_service.validate_already_synced_contact!

      # When we update the user, pass in the password and the latest Salesforce info.
      # (But not the tokens.)
      register_user_params = @sign_up_params
        .slice(:password, :password_confirmation)
        .merge(salesforce_contact_params)
      Honeycomb.add_field('register_user_account.salesforce_email', register_user_params[:email])

      # Don't send confirmation email yet; we do it explicitly below.
      @user.skip_confirmation_notification!
      @user.update(register_user_params.merge({
        # Mark the user as fully registered.
        registered_at: DateTime.now.utc,
        # Clear the signup and reset tokens, regardless of which was used.
        # https://github.com/heartcombo/devise/blob/57d1a1d3816901e9f2cc26e36c3ef70547a91034/lib/devise/models/recoverable.rb#L83
        signup_token: nil,
        # Note: don't clear the signup_token_sent_at b/c that's used to
        # determine whether the user was successfully created in the sync
        # See: SyncSalesforceContact#create_signup_token_and_send_to_salesforce
        reset_password_token: nil,
        reset_password_sent_at: nil,
      }))
      span.add_field('app.register_user.user_update_errors', @user.errors.to_json)
      # Allow error handling on model validation when called from a controller.
      yield @user if block_given?

      sync_contact_service.send_signup_date_to_salesforce(DateTime.now.utc)

      @user.send_confirmation_instructions
    rescue => e
      raise RegisterUserAccountError, e.message
    end

    # Note: we actually don't want to roll anything back if there are failures. We wouldn't
    # want to accidentailly delete a Canvas user and their work, or a Platform user and their
    # work. Instead, we're adding fields to the Honeycomb span to more easily diagnose and
    # troubleshoot the issues. As things arise, we should enhance this code to be re-runnable
    # so that if it fails you just have to try again and it will work if the underlying issue
    # is fixed.
  end

private

  # The new user params where Salesforce is the source of truth
  def salesforce_contact_params
    {
      email: @salesforce_contact.email,
      first_name: @salesforce_contact.firstname,
      last_name: @salesforce_contact.lastname,
    }
  end

end
