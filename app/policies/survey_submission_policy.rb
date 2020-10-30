class SurveySubmissionPolicy < ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    raise Pundit::NotAuthorizedError, "no project submission specified" unless record
    @user = user
    @record = record
  end

  def show?
    SurveyVersionPolicy.new(user, record.survey_version).show?
  end

  def new?
    SurveyVersionPolicy.new(user, record.survey_version).show?
  end

  def create?
    SurveyVersionPolicy.new(user, record.survey_version).show?
  end
end
