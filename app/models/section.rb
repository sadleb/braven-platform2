class Section < ApplicationRecord

  belongs_to :program
  belongs_to :logistic

  before_validation { name.try(:strip!) }
end
