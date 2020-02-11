class Organization < ApplicationRecord

  before_validation { self.name = self.name.strip }
  validates_presence_of :name
end
