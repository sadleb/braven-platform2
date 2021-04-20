class AccessToken < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, uniqueness: {case_sensitive: false}
  validates :key, presence: true, uniqueness: {case_sensitive: true}, length: {is: 255}
  validates :user, presence: true

  after_initialize :set_key
  before_update :set_key

  class << self
    def generate_key
      "#{Base64.urlsafe_encode64(SecureRandom.uuid)}.#{SecureRandom.urlsafe_base64(154)}"
    end
  end

private
  def set_key
    self.key ||= self.class.generate_key
  end
end
