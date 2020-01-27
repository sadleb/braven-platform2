class Email < ApplicationRecord
  
  validates :value, presence: true, format: { with: /\A[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\z/i }
  
  before_validation :downcase
  
  def as_json options={}
    attributes.slice('value')
  end
  
  private
  
  def downcase
    return if value.blank?
    self.value = value.downcase
  end
end
