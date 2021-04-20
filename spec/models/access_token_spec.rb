require 'rails_helper'

RSpec.describe AccessToken, type: :model do
  ############
  # Validation
  ############

  describe 'validation' do
    it { should validate_presence_of :name }
    it { should validate_presence_of :key }

    describe 'uniqueness' do
      before { create :access_token }

      it { should validate_uniqueness_of(:name).case_insensitive }
      it { should validate_uniqueness_of(:key) }
    end

    describe '255-char Base64 format key' do
      it { should allow_value('N2M2ODZiYzgtMTQ5MC00YTZhLThlOTQtYjhhZjJjNTZjODc0.4bgJEIOOI6n2ubk9dlvIYkcMjVln-7u0OPgWgIj7osAGBfxAs67AlWEy2zAb3mM2SBW0lM-U6Dz-4zbhQK-TKt4RR4Tqeqt7dfHpPzrT-mV-1kypNOdtNgM3FHOC70-v-3zqxW088b6Uf36Ugt6hsfR2XaHyCeKH0Bt4iEKQFKdaMUuB6o5cqDY6myY-5HAPsWk4k6qaxxPvGg').for(:key) }

      it { should_not allow_value(nil).for(:key)}
      it { should_not allow_value('1').for(:key)}
      it { should_not allow_value('N2M2ODZiYzgtMTQ5MC00YTZhLThlOTQtYjhhZjJjNTZjODc0.4bgJEIOOI6n2ubk9dlvIYkcMjVln-7u0OPgWgIj7osAGBfxAs67AlWEy2zAb3mM2SBW0lM-U6Dz-4zbhQK-TKt4RR4Tqeqt7dfHpPzrT-mV-1kypNOdtNgM3FHOC70-v-3zqxW088b6Uf36Ugt6hsfR2XaHyCeKH0Bt4iEKQFKdaMUuB6o5cqDY6myY-5HAPsWk4k6qaxxPvGgEXTRACHARSHERE').for(:key)}
    end
  end

  ###########
  # Callbacks
  ###########

  describe 'generating key on create' do
    let(:key) { 'N2M2ODZiYzgtMTQ5MC00YTZhLThlOTQtYjhhZjJjNTZjODc0.4bgJEIOOI6n2ubk9dlvIYkcMjVln-7u0OPgWgIj7osAGBfxAs67AlWEy2zAb3mM2SBW0lM-U6Dz-4zbhQK-TKt4RR4Tqeqt7dfHpPzrT-mV-1kypNOdtNgM3FHOC70-v-3zqxW088b6Uf36Ugt6hsfR2XaHyCeKH0Bt4iEKQFKdaMUuB6o5cqDY6myY-5HAPsWk4k6qaxxPvGg' }
    let(:access_token) { AccessToken.create name: 'Name' }

    before(:each) do
      allow(AccessToken).to receive(:generate_key).and_return(key)
    end

    it 'generates a valid key' do
      access_token
      expect(access_token.key).to eq(key)
    end

  end

  ###############
  # Class methods
  ###############

  describe 'generate_key' do
    subject { AccessToken.generate_key }

    # This is just making sure there isn't a really dumb bug that returns the same key each time.
    it "generates new keys each time" do
      attempts = 10
      keys = []

      attempts.times{ keys << AccessToken.generate_key }

      expect(keys.uniq.size).to eq(attempts)
    end
  end
end
