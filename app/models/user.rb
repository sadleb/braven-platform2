# frozen_string_literal: true
require 'salesforce_api'

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
  validates :email, :uuid, :first_name, :last_name, presence: true
  validate :password_complexity
  validates :salesforce_id, :signup_token, uniqueness: true, allow_blank: true
  # Enforce full 18-char Salesforce IDs.
  validates :salesforce_id, length: {is: 18}, allow_blank: true

  before_validation :set_uuid, on: :create

  # All sections where this user has any role.
  has_many :sections, -> { distinct }, through: :roles, source: :resource, source_type: 'Section'
  # All courses from above sections.
  has_many :courses, -> { distinct }, through: :sections

  # Role-specific associations, for efficiency.
  has_many :student_sections, -> { where("roles.name = ?", RoleConstants::STUDENT_ENROLLMENT) },
    through: :roles, source: :resource, source_type: 'Section'
  has_many :student_courses, -> { distinct }, through: :student_sections, source: :course
  # Careful with these, TA enrollments may include TAs, LCs, Staff, and guests.
  has_many :ta_sections, -> { where("roles.name = ?", RoleConstants::TA_ENROLLMENT) },
    through: :roles, source: :resource, source_type: 'Section'
  has_many :ta_courses, -> { distinct }, through: :ta_sections, source: :course

  def full_name
    [first_name, last_name].join(' ')
  end

  # A globally unique ID for this User in Canvas.
  # See here for more info: https://github.com/bebraven/platform/wiki/Salesforce-Sync
  def sis_id
    "BVUserId_#{id}_SFContactId_#{salesforce_id}"
  end

  # All sections with a specific role.
  def sections_with_role(role_name)
    Section.with_roles(role_name, self).distinct
  end

  # All sections for a specific course.
  def sections_by_course(course)
   Section.with_roles(section_roles.map(&:name), self).where(course: course)
  end

  # List of roles for Sections (aka roles excluding admin)
  def section_roles
    roles.where(resource_type: 'Section')
  end

  # List all roles for a given section
  def roles_by_section(section)
    roles.where(resource_type: 'Section', resource_id: section.id)
  end

  # The section with a student role in a given course.
  def student_section_by_course(course)
    student_sections.find_by(course: course)
  end

  # The section with the specified role in a given course.
  def section_with_role_by_course(role, course)
    sections_with_role(role).find_by(course: course)
  end

  # Removes the roles for all Sections in the specified course
  # and returns the list of Sections that the user was removed from
  def remove_section_roles(course)
    sections_removed = []
    RoleConstants::SECTION_ROLES.each { |role|
      sections = sections_with_role(role).where(course: course)
      sections.each do |section|
        remove_role role, section
        sections_removed << section
      end
    }
    sections_removed
  end

  # HerokuConnect helpers:
  # Note that these can't be an association (aka join) b/c in dev the HerokuConnect
  # and Platform databases aren't the same and you can't join across different databases.

  # Return a HerokuConnect::Contact record for this user.
  def contact
    @contact ||= HerokuConnect::Contact.find_by(sfid: salesforce_id)
  end

  # Return a HerokuConnect::Participant record for this user in the specified
  # course, assuming the user has a Salesforce Contact ID and the course has
  # a Salesforce Program ID.
  def participant(course)
    @participant ||= HerokuConnect::Participant.find_participant(salesforce_id, course.salesforce_program_id)
  end

  # Return a HerokuConnect::Cohort record for this user in the specified
  # course, assuming the user has a Salesforce Contact ID, the course has
  # a Salesforce Program ID, and the Participant is in a Cohort.
  def cohort(course)
    @cohort ||= participant(course)&.cohort
  end

  # Return a HerokuConnect::CohortSchedule record for this user in the specified
  # course, assuming the user has a Salesforce Contact ID, the course has
  # a Salesforce Program ID, and the Participant is in a Cohort Schedule.
  def cohort_schedule(course)
    @cohort_schedule ||= participant(course)&.cohort_schedule
  end

  # True if the user has confirmed their account and can log in.
  def confirmed?
    !!confirmed_at
  end

  # True if the user set their password through the initial sign_up flow.
  def registered?
    !!registered_at
  end

  def has_signed_up?
    registered? && confirmed?
  end

  def has_not_signed_up?
    !has_signed_up?
  end

  def admin?
    has_role? :admin
  end

  # If it's your own submission, or you're a TA/LC for the submission owner in that course.
  def can_view_submission_from?(target_user, course)
    return target_user == self || ta_for?(target_user, course) || lc_for?(target_user, course)
  end

  def is_enrolled?(course)
    return false if course.nil?
    courses.include?(course)
  end

  def is_enrolled_as_student?(course)
    return false if course.nil?
    student_courses.include?(course)
  end

  # Note: choosing not to include a is_enrolled_as_ta? method, because
  # TA_ENROLLMENT is used for people who aren't TAs (e.g. LCs), and that gets
  # confusing fast.

  # True iff the user is enrolled in SectionConstants::TA_SECTION for the course
  # and the target_user is a Fellow in the same course
  def ta_for?(target_user, course)
    # TODO: https://app.asana.com/0/1174274412967132/1199945855038779
    # LCs also use TA_ENROLLMENT, we need to introduce a separate LC_ENROLLMENT
    # role before we can check TA_ENROLLMENT for a course without specifying
    # the TA_SECTION.
    ta_section = sections_with_role(RoleConstants::TA_ENROLLMENT).teaching_assistants
      .find_by(course: course)
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

  # True if the user is enrolled in a course that the supplied `record`
  # references. E.g.:
  #
  #     user.can_access?(rise360_module_version)
  #     user.can_access?(project_submission)
  #
  # `record` can be any model instance that responds to `course` or `courses`,
  # except a User or a Section, where "can_access" would be meaningless.
  #
  # If `record` is a submission (or submission-like object, that has a `.user`
  # reference), this additionally checks whether the user has permission to
  # view submissions from `record.user`.
  #
  # When writing models that you intend to pass into this method, be sure to
  # always add a :course or :courses association, as appropriate! We'll raise
  # an exception if you don't, to help you remember.
  def can_access?(record)
    Honeycomb.start_span(name: 'user.can_access?') do
      Honeycomb.add_field('can_access.record.class', record.class.to_s)

      # Can't show something that doesn't exist.
      # Also exclude a couple things that don't make sense.
      return false if record.nil? || record.is_a?(User) || record.is_a?(Section)

      # Admins can always see the record.
      return true if admin?

      # Check enrollment.
      if record.respond_to?(:course)
        Honeycomb.add_field('can_access.record.course.id', record.course.id.to_s)

        # For submissions, we additionally check whether the user can view the submission.
        if record.respond_to?(:user)
          Honeycomb.add_field('can_access.record.user.id', record.user.id.to_s)

          return false unless can_view_submission_from?(record.user, record.course)
        end

        # Note, if by some weird edge case a user is trying to view their own
        # submission from a course they are no longer enrolled in, this will
        # return false and they will not be able to access it. This is desired
        # behavior (and also prevents people from creating a submission in a
        # course they're not enrolled in).
        return true if courses.include?(record.course)
      elsif record.respond_to?(:courses)
        return true if (courses & record.courses).any?
      else
        # Doesn't implement `.course` or `.courses`, so we don't know what to
        # do. Raise an exception to encourage the developer to add this missing
        # association.
        raise NotImplementedError.new "#{record.class} model does not implement course or courses; consider adding the appropriate association?"
      end

      false
    end
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

  def self.add_to_honeycomb_trace(user)
    Honeycomb.add_field('user.present?', user.present?)
    user&.add_to_honeycomb_trace
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
    set_sentry_user_context()
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
    set_sentry_user_context()
  end

  # Adds user fields useful to troubleshoot login issues to the current span
  def add_login_context_to_honeycomb_span
    Honeycomb.add_field('user.registered?', registered?)
    Honeycomb.add_field('user.confirmed?', confirmed?)
    Honeycomb.add_field('user.unconfirmed_email', unconfirmed_email)
  end

  # Sets the user context in Sentry which makes it easier to tie exceptions
  # to the user it happened for. Note that if you're running an operation
  # that adds multiple users to different spans, at the end you'll want to
  # call Sentry.set_user({}) to unset the global user.
  #
  # Ideally, we'd implement this using Sentry scopes but it's a lot more work
  # and the most common use-case here is seeing actual end-user exceptions when
  # hitting a page, where there is only one global user that exceptions should
  # be associated with.
  def set_sentry_user_context
    Sentry.set_user(id: id, email: email)
  end

  def honeycomb_id_fields_map
    {
      'user.id': id.to_s,
      'user.email': email,
      'salesforce.contact.id': salesforce_id,
      'canvas.user.id': canvas_user_id.to_s,
      'user.sis_id': sis_id,
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

  # Only checks basic password complexity, not minimum length. Devise's
  # config.password_length handles that.
  def password_complexity
    return unless password_required?
    return if password.blank? # Let other validators handle this.
    return if CheckPasswordComplexity.new(password).run

    Honeycomb.add_field('user.password_complexity.not_complex?', true)
    errors.add :password, :not_complex
  end

  # Override Devise's method in devise/models/confirmable.rb
  # to only send reconfirmation emails for registered users.
  # We want to be able to change their email at any time without
  # notifying them before they've actually created their account.
  def reconfirmation_required?
    return false unless registered?
    super
  end

  # Override Devise's method in devise/models/confirmable.rb
  # to directly change the email instead of setting the unconfirmed_email
  # column unless they are registered.
  # We want to be able to change their email at any time without
  # notifying them before they've actually created their account.
  def postpone_email_change?
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
