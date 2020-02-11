require 'grade_calculator'

class User < ApplicationRecord
  ADMIN_DOMAIN_WHITELIST = ['bebraven.org', 'beyondz.org']

  devise :cas_authenticatable, :rememberable
  
  has_many :project_submissions
  has_many :projects, :through => :project_submissions
  has_many :lesson_submissions
  has_many :lessons, :through => :lesson_submissions
  has_many :program_memberships
  has_many :programs, through: :program_memberships
  has_many :roles, through: :program_memberships

  has_many :user_sections
  has_many :sections, through: :user_sections do
    def as_fellow
      merge(UserSection.enrolled)
    end

    def as_lc
      merge(UserSection.facillitates)
    end

    def as_ta
      merge(UserSection.assists)
    end
  end

  before_create :attempt_admin_set, unless: :admin?
  
  validates :email, uniqueness: true
  validates :email, :first_name, :last_name, presence: true
  
  def full_name
    [first_name, last_name].join(' ')
  end
  
  def start_membership(program_id, role_id)
    find_membership(program_id, role_id) ||
      program_memberships.create(program_id: program_id, role_id: role_id, start_date: Date.today)
  end
  
  def end_membership(program_id, role_id)
    if program_membership = find_membership(program_id, role_id)
      program_membership.update! end_date: Date.yesterday
    else
      return false
    end
  end
  
  def update_membership(program_id, old_role_id, new_role_id)
    return if old_role_id == new_role_id
    
    end_membership(program_id, old_role_id)
    start_membership(program_id, new_role_id)
  end
  
  def find_membership(program_id, role_id)
    program_memberships.current.find_by(program_id: program_id, role_id: role_id)
  end
  
  def current_membership(program_id)
    program_memberships.current.find_by program_id: program_id
  end

  def total_grade(program)
    ::GradeCalculator.total_grade(self, program)
  end

  private
  
  def attempt_admin_set
    return if email.nil?
    
    domain = email.split('@').last
    self.admin = ADMIN_DOMAIN_WHITELIST.include?(domain)
  end
end
