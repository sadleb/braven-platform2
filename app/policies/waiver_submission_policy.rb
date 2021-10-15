class WaiverSubmissionPolicy < ApplicationPolicy
  attr_reader :user, :course

  def initialize(user, course)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    @user = user
    @course = course
  end

  # TODO: make sure they are in the course this is being launched for.
  # https://app.asana.com/0/1174274412967132/1199344732354185
  def launch?
    raise Pundit::NotAuthorizedError, "no course specified" unless course

    # launch the waiver if the user is a student in this course
    return true if enrolled_as_student_in_course?

    # if user is not a student, send error message - only students fill out waivers
    raise Pundit::NotAuthorizedError, message: "Only fellows need to complete waivers."
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

  private
    # TODO: refactor and use EnrolledPolicy here
    # https://app.asana.com/0/1174274412967132/1199344732354185
    # Returns true iff user has student enrollment in any section of course
    def enrolled_as_student_in_course?
      course.sections.each do |section|
        return true if user.has_role? RoleConstants::STUDENT_ENROLLMENT, section
      end
      false
    end
end
