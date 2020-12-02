require 'rails_helper'

RSpec.describe CourseResource, type: :model do
  it { should have_many :courses }
  it { should validate_presence_of :name }
end
