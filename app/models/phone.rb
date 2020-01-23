class Phone < ApplicationRecord

  validates :value, presence: true, uniqueness: true
  
  validate :value_must_contain_ten_digits
  
  before_validation :format_value
  
  def as_json options={}
    attributes.slice('value')
  end
  
  private
  
  def format_value
    return if value.blank?
    return unless has_required_digits?
    
    digits = only_digits(value)
    self.value = [digits[0,3], digits[3,3], digits[6,4]].join('-')
  end
  
  def value_must_contain_ten_digits
    unless has_required_digits?
      errors.add(:value, "must contain exactly ten digits")
    end
  end
  
  def only_digits string
    digits = string.gsub(/[^0-9]/, '').split('')
    digits.shift if digits.first == '1'
    
    digits.join('')
  end
  
  def required_digits
    10
  end
  
  def has_required_digits?
    return false if value.blank?
    only_digits(value).size == required_digits
  end
end
