class FormSubmissionPolicy < ApplicationPolicy
  attr_reader :user, :course

  def initialize(user, course)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    @user = user
    @course = course
  end

  def launch?
    raise Pundit::NotAuthorizedError, "no course specified" unless course

    # launch the form if the user is a student in this course
    return true if user.is_enrolled_as_student?(course)

    # if user is not a student, send error message - only students fill out forms
    raise Pundit::NotAuthorizedError, message: "Only Fellows need to complete forms."
  end

  def new?
    !!user
  end

  def create?
    !!user
  end

  def completed?
    !!user
  end

end
