require 'grade_calculator'
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
  has_many :lesson_submissions
  has_many :lessons, :through => :lesson_submissions

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

  # True if this user is a TA in the same section where target_user is a student.
  def ta_for?(target_user)
    sections_with_role(RoleConstants::TA_ENROLLMENT).each do |section|
      return true if target_user.has_role? RoleConstants::STUDENT_ENROLLMENT, section
    end
    false
  end

  def total_grade(course)
    ::GradeCalculator.total_grade(self, course)
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
