require 'rails_helper'

RSpec.describe Rise360ModuleVersion, type: :model do
  let!(:rise360_module_version) { create :rise360_module_version }

  it { should belong_to :rise360_module }
  it { should belong_to :user }
  it { should validate_presence_of :name }
  it { should validate_presence_of :quiz_questions }
  it { should validate_presence_of :activity_id }

  shared_examples 'read-only' do
    scenario 'throws an exception' do
      expect { subject }.to raise_error ActiveRecord::ReadOnlyRecord
    end
  end

  describe '#save' do
    subject { rise360_module_version.save! }
    it_behaves_like 'read-only'
  end

  describe '#update' do
    subject { rise360_module_version.update(name: 'New Name') }
    it_behaves_like 'read-only'
  end

  describe '#update attachment' do
    subject {
      rise360_module_version.rise360_zipfile.attach(
        io: File.open("#{Rails.root}/spec/fixtures/example_rise360_package.zip"),
        filename: 'example_rise360_package.zip',
        content_type: 'application/zip'
      )
    }
    it_behaves_like 'read-only'
  end

  describe '#create with attachment' do
    let(:admin_user) { create :admin_user }
    let(:rise360_module) { create :rise360_module_with_zipfile }
    subject { rise360_module.create_version!(admin_user) }

    before(:each) do
      allow(Rise360Util).to receive(:publish)
      allow(Rise360Util).to receive(:update_metadata!)
    end

    it 'makes a deep copy of the attachment' do
      version = subject
      expect(version.rise360_zipfile).not_to eq(rise360_module.rise360_zipfile)
    end

    it 'publishes the attachment' do
      version = subject
      expect(Rise360Util).to have_received(:publish).with(version.rise360_zipfile)
    end

    it 'copies metadata from the module' do
      version = subject
      expect(version.quiz_questions).to eq(rise360_module.quiz_questions)
      expect(version.activity_id).to eq(rise360_module.activity_id)
      expect(Rise360Util).not_to have_received(:update_metadata!).with(version)
    end
  end

  describe '#destroy' do
    it 'succeeds' do
      expect {
        rise360_module_version.destroy!
      }.to change(Rise360ModuleVersion, :count).by(-1)
    end
  end
end
