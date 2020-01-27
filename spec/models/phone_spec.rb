require 'rails_helper'

RSpec.describe Phone, type: :model do
  
  #############
  # Validations
  #############
  
  it { should validate_presence_of :value }
  
  describe 'validating uniqueness' do
    before { create :phone }
    it { should validate_uniqueness_of(:value).case_insensitive }
  end
  
  describe 'validating number of digits' do
    let(:phone) { build :phone }
    let(:error) { "must contain exactly ten digits" }
    
    it "requires exactly ten digits" do
      phone.value = '402111222'
      expect(phone).to_not be_valid
      expect(phone.errors[:value]).to include(error)
      
      phone.value = '40211122223'
      expect(phone).to_not be_valid
      expect(phone.errors[:value]).to include(error)
    end
    
    it "ignores non-numeric characters" do
      phone.value = '41234a567u89'
      phone.valid?
      expect(phone.errors[:value]).to_not include(error)
      
      phone.value = '41234f6s89'
      expect(phone).to_not be_valid
      expect(phone.errors[:value]).to include(error)
    end
    
    it "ignores leading one" do
      # leading one, plus ten valid digits
      phone.value = '14021112222'
      phone.valid?
      expect(phone.errors[:value]).to_not include(error)
      
      # ten digits, but the first is a one
      phone.value = "1402111222"
      expect(phone).to_not be_valid
      expect(phone.errors[:value]).to include(error)
    end
  end
  
  ##################
  # Instance methods
  ##################

  describe '#as_json' do
    let(:phone) { build :phone, value: '111-222-3333' }
    
    subject { phone.as_json }
    it { expect(subject['value']).to eq(phone.value) }
  end

  ###########
  # Callbacks
  ###########

  describe '#format_value' do
    let(:phone) { build :phone, value: value }
    let(:value) { '402-222-3333' }
    
    it "is called before validation" do
      expect(phone).to receive(:format_value).once
      phone.valid?
    end
    
    describe 'resulting value' do
      before { phone.valid? }
      subject { phone.value }
      
      describe 'with parentheses and spaces' do
        let(:value) { '(402) 222-3333' }
        it { should eq('402-222-3333') }
      end
      
      describe 'with dots' do
        let(:value) { '402.222.3333' }
        it { should eq('402-222-3333') }
      end
      
      describe 'with a leading one' do
        let(:value) { '1-402-222-3333' }
        it { should eq('402-222-3333') }
      end
    end
  end
end
