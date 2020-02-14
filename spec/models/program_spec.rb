require 'rails_helper'

RSpec.describe Program, type: :model do

  

  ##################
  # Instance methods
  ##################

  describe '#to_show' do
    let(:program) { build :program, name: 'Program' }
    subject { program.to_show }
    
    it { should eq({'name' => 'Program'}) }
  end
end
