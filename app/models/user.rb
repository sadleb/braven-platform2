require 'salesforce_api'
require 'canvas_api'

class User < ApplicationRecord
  rolify
  include Devise::Models::DatabaseAuthenticatable
  include Rails.application.routes.url_helpers

  # We're making the user model cas_authenticable, meaning that you need to go through the SSO CAS
  # server configured in config/initializers/devise.rb. However, "that" SSO server is "this" server
  # and the users that it authenticates are created in this database using :database_authenticable
  # functionality. This article was gold to help get this working:
  # https://jeremysmith.co/posts/2014-01-24-devise-cas-using-devisecasauthenticatable-and-casino/
  if ENV['BZ_AUTH_SERVER']
    # See: config/initializers/devise.rb for what this is all about.
    devise :cas_authenticatable, :rememberable
  else
    # TODO: trackable for more info on sign-in activity.
    #devise :cas_authenticatable, :rememberable, :registerable, :confirmable, :validatable, :recoverable, :trackable
    devise :cas_authenticatable, :rememberable, :registerable, :confirmable, :validatable, :recoverable
  end

  self.per_page = 100

  has_many :project_submissions
  has_many :projects, :through => :project_submissions

  has_many :access_tokens

  validates :email, uniqueness: true
  validates :email, :first_name, :last_name, presence: true
  validates :email, presence: true

  # All sections where this user has any role.
  has_many :sections, -> { distinct }, through: :roles, source: :resource, source_type: 'Section'

  def full_name
    [first_name, last_name].join(' ')
  end

  # All sections with a specific role.
  def sections_with_role(role_name)
    Section.with_roles(role_name, self).distinct
  end

  # List of roles for Sections (aka roles excluding admin)
  def section_roles
    roles.where(resource_type: 'Section')
  end

  # The section with a student role in a given course.
  def student_section_by_course(course)
    sections_with_role(RoleConstants::STUDENT_ENROLLMENT).find_by(course: course)
  end

  # True if the user has confirmed their account and can log in.
  def confirmed?
    !!confirmed_at
  end

  # True if the user set their password through the initial sign_up flow.
  def registered?
    !!registered_at
  end

  def admin?
    has_role? :admin
  end

  def can_view_submission_from?(target_user, course)
    return ta_for?(target_user, course) || lc_for?(target_user, course)
  end

  # True iff the user is enrolled in SectionConstants::TA_SECTION for the course
  # and the target_user is a Fellow in the same course
  def ta_for?(target_user, course)
    # TODO: https://app.asana.com/0/1174274412967132/1199945855038779
    # LCs also use TA_ENROLLMENT, we need to introduce a separate LC_ENROLLMENT
    # role before we can check TA_ENROLLMENT for a course without specifying
    # the TA_SECTION.
    ta_section = sections_with_role(RoleConstants::TA_ENROLLMENT).find_by(
      course: course,
      name: SectionConstants::TA_SECTION,
    )
    student_section = target_user.student_section_by_course(course)
    return ta_section && student_section ? true : false
  end

  def lc_for?(target_user, course)
    # TODO: https://app.asana.com/0/1174274412967132/1199945855038779
    # We need a separate LC_ENROLLMENT in Canvas and our RoleConstants
    # and maybe Salesforce to differentiate between LCs and TAs.
    lc_section = sections_with_role(RoleConstants::TA_ENROLLMENT).find_by(
      course: course,
    )
    student_section = target_user.student_section_by_course(course)
    return lc_section.present? && student_section.present? && lc_section.id == student_section.id
  end

  def can_take_attendance_for_all?
    admin? or has_role? RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL
  end

  def can_sync_from_salesforce?
    admin? or has_role? RoleConstants::CAN_SYNC_FROM_SALESFORCE
  end

  def can_send_new_sign_up_email?
    admin? or has_role? RoleConstants::CAN_SEND_NEW_SIGN_UP_EMAIL
  end

  # The email address to log in with after the confirmation link is clicked.
  # For the initial account setup, this is just the email. But if the email is
  # changed, it becomes the unconfirmed_email until they reconfirm
  def after_confirmation_login_email
    unconfirmed_email || email
  end

   # Normally, users get an email with a sign_up link as part of the "Welcome"
   # email generated from Campaign Monitor a week or two before program launch.
   # This email is for folks who missed (or lost) that and need their account creation
   # sign-up link. It's generic and meant to be sent to any user, Fellow or LC.
  def send_sign_up_email!

    # TODO: use token instead of SF ID. Note that we should raise an error here if the token
    # has not been generated and stored in SF. It means Sync From Salesforce hasn't run
    # or the user was created from the Admin dash and there is a bug where it doesn't generate the token.
    # https://app.asana.com/0/1174274412967132/1200147504835146/f
    # Make sure you update the link in app/controllers/users/passwords_controller.rb too
    sign_up_url = new_user_registration_url(u: salesforce_id, protocol: 'https')

    SendSignUpEmailMailer.with(email: email, first_name: first_name, sign_up_url: sign_up_url)
      .sign_up_email.deliver_now
  end

  def self.search(query)
    search_str = query.strip
    search_str.downcase!
    to_sql_pattern = ->(str) { "%#{str.gsub('*', '%')}%" } # 'ian*test@bebrave' would turn into '%ian%test@bebrave%' and SQL would return the email: 'brian+testblah@bebraven.org'
    if search_str.include? '@'
      where('lower(email) like ?', to_sql_pattern[search_str] )
    else
      search_terms = search_str.split("\s")
      if search_terms.size <= 1
        pattern = to_sql_pattern[search_str]
        where('lower(first_name) like ? OR lower(last_name) like ? OR lower(email) like ?', pattern, pattern, pattern)
      else
        where('lower(first_name) like ? AND lower(last_name) like ?', to_sql_pattern[search_terms.first], to_sql_pattern[search_terms.last])
      end
    end
  end

protected

  # Allow empty passowrds for non-registered users.
  # This lets us create accounts with empty passwords in the
  # Sync flow, when login is still impossible, but prevents
  # empty passwords once the user goes through the sign_up
  # flow and sets their password for the first time.
  def password_required?
    return false unless registered?
    super
  end

end
