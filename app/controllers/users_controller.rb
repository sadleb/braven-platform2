# frozen_string_literal: true
require 'salesforce_api'

class UsersController < ApplicationController
  layout 'admin'

  UserAdminError = Class.new(StandardError)

  # Note that DryCrud takes care of the standard actions
  before_action :find_user, only: %i[show_send_signup_email send_signup_email send_confirm_email]

  def index
    authorize User
    current_page = params[:page]
    @users = if params[:search]
               User.search(params[:search])
             else
               User.order(created_at: :desc)
             end

    respond_to do |format|
      format.html do
        @users = @users.paginate(page: current_page)
        render
      end
    end
  end

  def show
    authorize @user
  end

  def new
    @user = User.new
    authorize @user
  end

  def create
    authorize User
    @user = User.create(user_params.merge(confirmed_at: DateTime.now, registered_at: DateTime.now))

    if @user.persisted?
      redirect_to users_path, notice: 'User was added successfully'
    else
      render action: :new
    end
  end

  def edit
    authorize @user
  end

  def update
    authorize @user

    # Don't update the password if it's blank (unchanged).
    filtered_user_params = user_params.reject { |k, v| k == "password" and v.blank? }

    # Don't blow away their non-global roles
    new_global_role_ids = filtered_user_params[:role_ids]
    existing_role_ids_minus_global = @user.role_ids.reject { |rid| Role.global.ids.include?(rid) }
    new_role_ids = new_global_role_ids + existing_role_ids_minus_global
    filtered_user_params[:role_ids] = new_role_ids

    # Convert empty SF IDs to nil, to comply with the uniqueness constraint.
    filtered_user_params[:salesforce_id] = nil if filtered_user_params[:salesforce_id].blank?

    user_changes_persisted = @user.update(filtered_user_params)

    if user_changes_persisted
      redirect_to user_path(@user), notice: 'User was changed successfully'
    else
      render action: :edit
    end
  end

  def send_confirm_email
    authorize @user
    raise UserAdminError.new('Cannot send confirmation email to unregistered user') unless @user.registered?
    raise UserAdminError.new('Cannot send confirmation email to already confirmed user') if @user.confirmed?
    @user.send_confirmation_instructions
    redirect_to user_path(@user), notice: 'New confirmation email sent! When they click "Confirm Email" they will have finished their account setup.'
  end

  def show_send_signup_email
    authorize @user
    raise UserAdminError.new('Cannot send sign-up email to already registered user') if @user.registered?
  end

  def send_signup_email
    authorize @user
    raise UserAdminError.new('Cannot send sign-up email to already registered user') if @user.registered?

    if !@user.signup_period_valid?
      raw_signup_token = @user.set_signup_token!

       # Set new User signup token on the Salesforce Contact record
       # Note: call it with the raw token, *not* the encoded one from the database b/c that's
       # what is needed in the Account Create Link.
      SalesforceAPI.client.update_contact(@user.salesforce_id, {'Signup_Token__c': raw_signup_token })
    end

    @user.send_signup_email!
    redirect_to user_path(@user), notice: 'Email sent!'
  end

  def destroy
    authorize @user
    @user.delete
    redirect_to users_path, notice: 'User has been deleted'
  end

  private

  def find_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :canvas_user_id, :salesforce_id, role_ids: [])
  end
end
