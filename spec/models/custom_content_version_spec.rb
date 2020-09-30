require 'rails_helper'

RSpec.describe CustomContentVersion, type: :model do
  it { should belong_to :course_content }
end
