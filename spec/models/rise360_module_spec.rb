require 'rails_helper'
require 'rise360_util'

RSpec.describe Rise360Module, type: :model do
  # Note: we use a module that doesn't have a zipfile attached so we don't
  # trigger network calls when calling create!
  let(:rise360_module) { create :rise360_module }

  it { should validate_presence_of :name }

  describe '#last_version' do
    subject { rise360_module.last_version }
    it { should eq(nil) }
  end

  describe '#versions' do
    subject { rise360_module.versions }
    it { should eq([]) }
  end

  describe '#new_version' do
    let(:user) { create :admin_user }
    subject { rise360_module.new_version(user) }

    it { should be_a Rise360ModuleVersion }

    it 'copies the name' do
      expect(subject.name).to eq(rise360_module.name)
    end

    it 'copies the zipfile' do
      expect(subject.rise360_zipfile.attached?).to eq(rise360_module.rise360_zipfile.attached?)
    end
  end

  describe '#create_version!' do
    let(:user) { create :admin_user }
    subject { rise360_module.create_version!(user) }

    it { should be_a Rise360ModuleVersion }

    it 'creates a new version' do
      expect {
        subject
      }.to change(Rise360ModuleVersion, :count).by(1)
    end
  end
end
