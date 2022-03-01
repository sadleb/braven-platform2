class DiscordSignupPolicy < ApplicationPolicy
  # Pass in a Course object as the `record`, if you want to check the
  # launch? policy.

  def launch?
    # Requires logged-in user enrolled in the current course.
    # `record` is a Course.
    !!user && user.is_enrolled?(record)
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

  def reset_assignment?
    !!user
  end

  def publish?
    edit?
  end
  
  def unpublish?
    edit?
  end

end
