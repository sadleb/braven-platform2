class Program < ApplicationRecord
  has_many :program_memberships
  has_many :users, through: :program_memberships
  has_many :roles, through: :program_memberships

  validates :name, presence: true, uniqueness: {case_sensitive: false}
  
  def to_show
    attributes.slice('name')
  end
end
