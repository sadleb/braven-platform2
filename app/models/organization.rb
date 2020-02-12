class Organization < ApplicationRecord

  before_validation { name.strip! }
  validates_presence_of :name
end
