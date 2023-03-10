# Modified from: https://gist.github.com/killthekitten/b9a7b11530c44e788a31ec53e5ef0dad
#
# Workaround for CSRF protection bug.
#
# https://github.com/rails/rails/issues/21948
# The bug:
# The rails session cookie is not persistent, therefore it expires when the page is loaded from cache
# (i.e. when browser restores tabs on restart https://www.youtube.com/watch?v=bKDu0qMT4HM)
# which leads to an `InvalidAuthenticityToken` when the user submits a form from that page.
#
# Workaround:
# We decided to move the CSRF token from the session cookie into a separate persistent cookie.
module ActionController
  module RequestForgeryProtection
    COOKIE_NAME = :_csrf_token

    # Override https://github.com/rails/rails/blob/10c0b5939f8d7f3959990dd4eeb59f0b864147df/actionpack/lib/action_controller/metal/request_forgery_protection.rb#L430
    def real_csrf_token(session)
      csrf_token = cookies.encrypted[COOKIE_NAME] || session[:_csrf_token]
      csrf_token ||= generate_csrf_token
      cookies.encrypted[COOKIE_NAME] ||= {
        value: csrf_token,
        expires: 1.year.from_now,
        httponly: true
      }
      session[:_csrf_token] = csrf_token
      decode_csrf_token(csrf_token)
    end
  end
end

# http://blog.plataformatec.com.br/2013/08/csrf-token-fixation-attacks-in-devise/
# (devise-4.2.0/lib/devise/hooks/csrf_cleaner.rb):
Warden::Manager.after_authentication do |_record, warden, _options|
  clean_up_for_winning_strategy = !warden.winning_strategy.respond_to?(:clean_up_csrf?) ||
    warden.winning_strategy.clean_up_csrf?
  if Devise.clean_up_csrf_token_on_authentication && clean_up_for_winning_strategy
    warden.cookies.delete(ActionController::RequestForgeryProtection::COOKIE_NAME)
  end
end
