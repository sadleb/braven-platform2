class UserSection < ApplicationRecord

  ENROLLED = 'enrolled'
  FACILLITATES = 'facillitates'
  ASSISTS = 'assists'

  belongs_to :user
  belongs_to :section

  validates :type, inclusion: { in: [ENROLLED, FACILLITATES, ASSISTS] }

  scope :enrolled, -> { where(type: ENROLLED) }
  scope :facillitates, -> { where(type: FACILLITATES) }
  scope :assists, -> { where(type: ASSISTS) }
end