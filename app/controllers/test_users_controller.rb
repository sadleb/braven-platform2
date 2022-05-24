# frozen_string_literal: true
require 'salesforce_api'

class TestUsersController < ApplicationController
  before_action :set_program_options, only: [:index]

  layout 'admin'

  def index
    authorize :TestUser
    @role_options = [
      SalesforceConstants::Role::FELLOW,
      SalesforceConstants::Role::LEADERSHIP_COACH,
      SalesforceConstants::Role::TEACHING_ASSISTANT,
      SalesforceConstants::Role::COACH_PARTNER,
      SalesforceConstants::Role::STAFF,
      SalesforceConstants::Role::FACULTY
    ]
  end

  def post
    authorize :TestUser
    GenerateTestUsersJob.perform_later(current_user.email, params.to_unsafe_h)
    redirect_to generate_test_users_path, notice: 'The generation process was started. Watch out for an email'
  end

  def cohort_schedules
    authorize :TestUser
    cohort_schedules = HerokuConnect::Program.find(params[:id]).cohort_schedules
    render :json => cohort_schedules
  end

  def cohort_sections
    authorize :TestUser
    cohorts = HerokuConnect::CohortSchedule.find(params[:id]).cohorts
    render :json => cohorts
  end

  def get_program_tas
    authorize :TestUser
    tas = HerokuConnect::Program.find(params[:id]).ta_participants.filter_map {|p| p if p.is_teaching_assistant? }
    render :json => tas
  end

private
  def set_program_options
    @program_options = HerokuConnect::Program.current_and_future_programs.pluck(:name, :sfid)
  end
end