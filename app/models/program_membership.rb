class ProgramMembership < ApplicationRecord
  belongs_to :user
  belongs_to :program
  belongs_to :role
  
  scope :current, -> { today = Date.today; where("start_date <= ?", today).where("end_date >= ? or end_date is null", today) }
  
  def current?
    today = Date.today
    start_date <= today && (end_date.nil? || end_date >= today)
  end
end
