class DiscordSignupPolicy < ApplicationPolicy
  # Pass in a Course object as the `record`, if you want to check the
  # launch? policy.

  def launch?
    # Requires logged-in user enrolled in the current course.
    !!user && is_enrolled?
  end

  def oauth?
    # We don't confirm enrollment here, bc the #oauth action doesn't do anything
    # except exchange their oauth code for their oauth token. And it'd be a pain
    # to look up the lti launch and course from the #oauth action too.
    !!user
  end

  def completed?
    !!user
  end

  def publish?
    edit?
  end
  
  def unpublish?
    edit?
  end

private
  # TODO: refactor and use EnrolledPolicy here
  # https://app.asana.com/0/1174274412967132/1199344732354185
  # Returns true iff user has any type of enrollment in any section of course
  def is_enrolled?
    record.sections.each do |section|
      RoleConstants::SECTION_ROLES.each do |role|
        return true if user.has_role? role, section
      end
    end
    false
  end
end
