# frozen_string_literal: true
class UsersController < ApplicationController
  layout 'admin'

  # Note that DryCrud takes care of the standard actions
  before_action :find_user, only: %i[confirm register show_send_sign_up_email send_sign_up_email]

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

    user_changes_persisted = @user.update(filtered_user_params)

    if user_changes_persisted
      redirect_to user_path(@user), notice: 'User was changed successfully'
    else
      render action: :edit
    end
  end

  def confirm
    authorize @user

    if @user.confirmed?
      redirect_to user_path(@user), notice: 'User already confirmed'
    else
      @user.confirm
      redirect_to user_path(@user), notice: 'User has been confirmed'
    end
  end

  def register
    authorize @user

    if @user.registered_at.present?
      redirect_to user_path(@user), notice: 'User already registered'
    else
      @user.update!(registered_at: DateTime.now)
      redirect_to user_path(@user), notice: 'User has been registered'
    end
  end
  def show_send_sign_up_email
    authorize @user
  end

  def send_sign_up_email
    authorize @user

    @user.send_sign_up_email!
    redirect_to send_new_sign_up_email_user_path(@user), notice: 'Email sent!'
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
