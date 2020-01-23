require 'rails_helper'

RSpec.describe Address, type: :model do
  let(:postal_code) { create :postal_code, code: '68521', city: 'Lincoln', state: 'NE'}
  
  #############
  # Validations
  #############

  it { should validate_presence_of :line1 }
  it { should validate_presence_of :city }
  it { should validate_presence_of :state }
  it { should validate_presence_of :zip }
  
  describe 'validating state format is a two-char capital string' do
    # disable state normalization for validations
    before { allow_any_instance_of(Address).to receive(:set_state) }
    
    it { should allow_value('NE').for(:state) }
    it { should allow_value('AK').for(:state) }
    it { should allow_value('TX').for(:state) }

    it { should_not allow_value('ne').for(:state) }
    it { should_not allow_value('Nebraska').for(:state) }
    it { should_not allow_value('Neb').for(:state) }
    it { should_not allow_value('123').for(:state) }
  end

  ###########
  # Callbacks
  ###########
  
  describe '#set_city' do
    let(:address) { build :address, city: city, zip: zip }
    let(:city) { 'Lincoln' }
    let(:zip) { '68521' }
    
    before { postal_code }
    
    it "is called before validation" do
      expect(address).to receive(:set_city).once
      address.valid?
    end
    
    describe 'resulting value' do
      before { address.valid? }
      subject { address.city }
      
      describe 'when city is provided' do
        let(:city) { 'Omaha' }
        it { should eq('Omaha') }
      end
      
      describe 'when city is omitted, but zip is in database' do
        let(:city) { nil }
        it { should eq('Lincoln')}
      end
      
      describe 'when city is omitted, and zip is not recognized' do
        let(:city) { nil }
        let(:zip) { '10001' }
        
        it { should be_nil }
      end
    end
  end
  
  describe '#set_state' do
    let(:address) { build :address, state: state, zip: zip }
    let(:state) { 'NE' }
    let(:zip) { '68521' }
    
    before { postal_code }
    
    it "is called before validation" do
      expect(address).to receive(:set_state).once
      address.valid?
    end
    
    describe 'resulting value' do
      before { address.valid? }
      subject { address.state }
      
      describe 'when state is provided' do
        let(:state) { 'IA' }
        it { should eq('IA') }
      end
      
      describe 'when state is omitted, but zip is in database' do
        let(:state) { nil }
        it { should eq('NE')}
      end
      
      describe 'when state is omitted, and zip is not recognized' do
        let(:state) { nil }
        let(:zip) { '10001' }
        
        it { should be_nil }
      end
      
      describe 'when state full name is provided instead of abbreviation' do
        [
          'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut', 
          'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 
          'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 'Michigan', 
          'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire',
          'New Jersey', 'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio',
          'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota',
          'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington', 'West Virginia',
          'Wisconsin', 'Wyoming', 'Puerto Rico', 'Washington D.C.', 'Washington DC', 'D.C.'
        ].each do |state_name|
          it "converts #{state_name} to a two-character abbreviation" do
            address = Address.new state: state_name
            address.valid?
            
            expect(address.state).to match(/\A[A-Z]{2}\z/)
          end
        end
      end
    end
  end
  
  ##################
  # Instance methods
  ##################

  describe '#as_json' do
    let(:address) { build :address, line1: line1, line2: line2, city: city, state: state, zip: zip }
    let(:line1) { '123 Way Street' }
    let(:line2) { 'Apt C' }
    let(:city) { 'Lincoln' }
    let(:state) { 'NE' }
    let(:zip) { '68521' }
    
    subject { address.as_json }
    
    it { expect(subject['line1']).to eq(line1) }
    it { expect(subject['line2']).to eq(line2) }
    it { expect(subject['city']).to eq(city) }
    it { expect(subject['state']).to eq(state) }
    it { expect(subject['zip']).to eq(zip) }
    
    describe 'when line2 is nil' do
      let(:line2) { nil }
      it { expect(subject).to_not have_key('line2')}
    end
    
    describe 'when line2 is blank' do
      let(:line2) { '' }
      it { expect(subject).to_not have_key('line2')}
    end
  end
end
