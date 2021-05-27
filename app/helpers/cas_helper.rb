require "addressable/uri"

module CasHelper

  # We don't want to redirect to arbitrary service URLs, since that's a dangerous open redirect.
  # We check each of these regexes against the host portion of the service URL.
  ALLOWED_SERVICES = [
    /^(.+\.)?bebraven\.org$/,
    /^(.+\.)?braven\.org$/,
    /^braven.instructure.com$/,
    /^braven$/,
    /^#{ENV['SPEC_HOST']}$/,
    /^localhost$/,
    /^127.0.0.1$/,
    /^platformweb$/,
    /^boosterplatformweb$/,
    /^canvasweb$/,
  ]

  # Allows us to use Devise view stuff in the CasController.
  # See: https://stackoverflow.com/questions/4081744/devise-form-within-a-different-controller

  def resource_name
    @resource_name ||= :user
  end

  def resource
    @resource ||= resource_name.to_s.classify.constantize.new
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[resource_name]
  end

  # If we can't determine which login service_url to use, this is the default for
  # the user. If there is no user, use the Canvas service since that is the main
  # application most users will be trying to access. This happens if someone tries
  # to login directly to the platform cas/login path for example (also maybe on logout
  # or in other situations where the session has expired)
  #
  # Note: keep the logic for which service to use for SSO auth in sync with
  # the logic for which homepage to send them to after login in:
  # CasSessionsController#after_sign_in_path_for(user)
  def default_service_url_for(user)
     login_service_url = CanvasConstants::CAS_LOGIN_URL
     if user&.admin?
       login_service_url = ::Devise.cas_service_url(request.url, devise_mapping)
     end
     login_service_url
  end

  # Only allow redirects to services we own.
  # See ALLOWED_SERVICES above.
  def safe_service_url(service)
    parsed_service = Addressable::URI.parse(service)
    if parsed_service&.host
      ALLOWED_SERVICES.each do |regex|
        if regex.match parsed_service.host
          return service
        end
      end
    elsif service&.start_with? '/'
      # Service is a relative url, so it's safe.
      # Note '//example.com/` also starts with a slash and is *not* relative, but that
      # would have a parsed `host` so it would be caught in the branch above.
      return service
    else
      # `redirect_to '.evil.com'` is valid in Rails, so we need to hard-exclude
      # anything that doesn't start with a slash.
      return nil
    end

    # If we get here, the specified service is unsafe.
    # Default to nil, same as if this param was unset.
    nil
  end

end
