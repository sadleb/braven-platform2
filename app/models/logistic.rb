class Logistic < ApplicationRecord

  belongs_to :program

  before_validation { day_of_week.strip! }
  before_validation { time_of_day.strip! }

  validates_presence_of :day_of_week
  validates_presence_of :time_of_day
  validates :day_of_week, inclusion: { in: %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday) }
end
