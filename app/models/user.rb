require 'salesforce_api'
require 'canvas_api'

class User < ApplicationRecord
  rolify
  include Devise::Models::DatabaseAuthenticatable

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

  # True if the user has confirmed their account and can login.  
  def confirmed?
    !!confirmed_at
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

end
