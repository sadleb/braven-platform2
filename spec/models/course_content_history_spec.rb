require 'rails_helper'

RSpec.describe CourseContentHistory, type: :model do
  it { should belong_to :course_content }
end
