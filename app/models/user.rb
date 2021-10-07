# frozen_string_literal: true
require 'salesforce_api'
require 'canvas_api'

class SignupTokenError < StandardError; end

class User < ApplicationRecord
  rolify
  include Devise::Models::DatabaseAuthenticatable
  include Rails.application.routes.url_helpers

  # Note: there is also a :trackable configuration if we want more info on sign-in activity.
  devise :cas_authenticatable, :rememberable, :registerable, :confirmable, :validatable, :recoverable

  # Add secret fields to exclude them from serialization/printing in addition to Devise's default ones.
  UNSAFE_ATTRIBUTES_FOR_SERIALIZATION = [
    :signup_token, :signup_token_sent_at,
    :linked_in_access_token, :linked_in_state,
  ]

  self.per_page = 100

  has_many :project_submissions
  has_many :projects, :through => :project_submissions

  has_many :access_tokens

  validates :email, :uuid, uniqueness: true
  validates :salesforce_id, :signup_token, uniqueness: true, allow_blank: true
  validates :email, :uuid, :first_name, :last_name, presence: true
  # Enforce full 18-char Salesforce IDs.
  validates :salesforce_id, length: {is: 18}, allow_blank: true

  before_validation :set_uuid, on: :create

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

  def can_send_account_creation_emails?
    admin? or has_role? RoleConstants::CAN_SEND_ACCOUNT_CREATION_EMAILS
  end

  def can_schedule_discord?
    admin? or has_role? RoleConstants::CAN_SCHEDULE_DISCORD
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
  # Note passing in the raw token is optional and only serves to reduce SF calls.
  def send_signup_email!(raw_signup_token=nil)
    if raw_signup_token.blank?
      # No token passed in, so let's fetch it from Salesforce.
      # Raise an error here if the token has not been generated and stored in SF.
      # It means Sync From Salesforce hasn't run or the user was created from the
      # Admin dash, which doesn't generate the token.
      raise SignupTokenError.new('Blank Salesforce ID') if salesforce_id.blank?
      signup_token = SalesforceAPI.client.get_contact_signup_token(salesforce_id)
      raise SignupTokenError.new('No signup token found') if signup_token.blank?
    else
      # Since we got a token passed in, we don't need to fetch from Salesforce.
      signup_token = raw_signup_token
    end

    sign_up_url = new_user_registration_url(signup_token: signup_token, protocol: 'https')
    SendSignupEmailMailer.with(email: email, first_name: first_name, sign_up_url: sign_up_url)
      .signup_email.deliver_now
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

  # Used during the sign_up / registration process to securely
  # identify users. Modeled after and uses Devise methods, but not
  # actually a part of Devise.
  # https://github.com/heartcombo/devise/blob/5d5636f03ac19e8188d99c044d4b5e90124313af/lib/devise/models/recoverable.rb
  def set_signup_token!
    raw, enc = Devise.token_generator.generate(self.class, :signup_token)

    self.signup_token = enc
    self.signup_token_sent_at = DateTime.now.utc
    save!
    raw
  end

  # https://github.com/heartcombo/devise/blob/57d1a1d3816901e9f2cc26e36c3ef70547a91034/lib/devise/models/recoverable.rb#L77
  def signup_period_valid?
    # Note we reuse the confirm_within value from Devise global config.
    signup_token_sent_at && signup_token_sent_at.utc >= User.confirm_within.ago.utc
  end

  # Find user by signup_token, if it exists. If not, return nil.
  # Call it with the raw token, *not* the encoded one from the database.
  def self.with_signup_token(token)
    encoded_signup_token = Devise.token_generator.digest(User, :signup_token, token)
    User.find_by(signup_token: encoded_signup_token)
  end

  # Adds common Honeycomb fields to every span in the trace. Useful to be able to group
  # any particular field you're querying for by user.
  #
  # IMPORTANT: if you need information on multiple users in a trace, DO NOT USE THIS.
  # Whatever the values for the last user are will overwrite all the other user info.
  # Instead, you can use add_to_honeycomb_span() for each user. You'll have to query for
  # fields in that particular span to be able to group by user.
  def add_to_honeycomb_trace
    honeycomb_id_fields_map.each { |field, value| Honeycomb.add_field_to_trace(field, value) }
    add_login_context_to_honeycomb_span()
  end

  # Adds common Honeycomb fields only to the current span. Useful if you need to add
  # user information for multiple Users in a given trace.
  #
  # Note: you must pass in the 'caller_name', in other words the name of the calling class,
  # so that we can prefix the standard field name. We do this b/c if add_to_honeycomb_trace()
  # were called anywhere during the current trace, these values would be overwritten.
  def add_to_honeycomb_span(caller_name)
    raise ArgumentError.new("caller_name is blank") if caller_name.blank?
    honeycomb_id_fields_map.each { |field, value| Honeycomb.add_field("#{caller_name}.#{field}", value) }
    add_login_context_to_honeycomb_span()
  end

  # Adds user fields useful to troubleshoot login issues to the current span
  def add_login_context_to_honeycomb_span
    Honeycomb.add_field('user.registered?', registered?)
    Honeycomb.add_field('user.confirmed?', confirmed?)
    Honeycomb.add_field('user.unconfirmed_email', unconfirmed_email)
  end

  def honeycomb_id_fields_map
    {
      'user.id': id.to_s,
      'user.email': email,
      'salesforce.contact.id': salesforce_id,
      'canvas.user.id': canvas_user_id.to_s,
    }
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

  # Redefine method that filters sensitive fields when serializing/printing
  # See: vendor/bundle/ruby/3.0.0/gems/devise-4.8.0/lib/devise/models/authenticatable.rb
  def serializable_hash(options = nil)
    super({:except => UNSAFE_ATTRIBUTES_FOR_SERIALIZATION})
  end

private

  def set_uuid
    self.uuid ||= SecureRandom.uuid()
  end

end
