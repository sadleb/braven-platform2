require 'rails_helper'
require 'rise360_util'

RSpec.describe Rise360Module, type: :model do
  # Note: we use a module that doesn't have a zipfile attached so we don't
  # trigger network calls when calling create!
  let(:rise360_module) { create :rise360_module }

  it { should validate_presence_of :name }

  describe '#update' do
    before(:each) do
      allow(Rise360Util).to receive(:publish)
      allow(Rise360Util).to receive(:update_metadata!)
    end

    context 'does not change the rise360_zipfile' do
      subject { rise360_module.update!(name: 'New Module Title') }

      it 'does not re-publish to S3' do
        subject
        expect(Rise360Util).not_to have_received(:publish)
      end

      it 'does not update metadata' do
        subject
        expect(Rise360Util).not_to have_received(:update_metadata!)
      end
    end

    context 'attaches a new rise360_zipfile' do
      subject {
        rise360_module.rise360_zipfile.attach(
          io: File.open("#{Rails.root}/spec/fixtures/example_rise360_package.zip"),
          filename: 'example_rise360_package.zip',
          content_type: 'application/zip'
        )
      }

      it 'attaches the zipfile' do
        subject
        expect(rise360_module.reload.rise360_zipfile.attached?).to be true
      end

      it 're-publishes to S3' do
        subject
        expect(Rise360Util).to have_received(:publish).once
      end

      it 'updates metadata' do
        subject
        expect(Rise360Util).to have_received(:update_metadata!).once
      end
    end
  end

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

    it 'copies the metadata' do
      expect(subject.quiz_questions).to eq(rise360_module.quiz_questions)
      expect(subject.activity_id).to eq(subject.activity_id)
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
