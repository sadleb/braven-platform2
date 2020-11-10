require 'rails_helper'

RSpec.describe BaseCourseCustomContentVersion, type: :model do

  let(:course) { create :course_with_canvas_id }
  let(:custom_content_version) { create :custom_content_version }
  let(:base_course_custom_content_version) { create :base_course_custom_content_version, base_course: course, custom_content_version: custom_content_version }
  
  describe '#valid?' do
    subject { base_course_custom_content_version }

    context 'when valid attributes' do
      it { is_expected.to be_valid }
    end
  end

  describe '#publish_latest!' do
    let(:canvas_client) { double(CanvasAPI) }
    let(:admin_user) { create :admin_user }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    end

    context 'assignment exists in Canvas' do
      before(:each) do
        allow(canvas_client)
          .to receive(:get_assignment)
          .with(course.canvas_course_id, base_course_custom_content_version.canvas_assignment_id)
          .and_return({ assignment: { id: base_course_custom_content_version.canvas_assignment_id } })
      end

      it 'creates a new version' do
        expect {
          base_course_custom_content_version.publish_latest!(admin_user)
        }.to change(CustomContentVersion, :count).by(1)
      end

      it 'updates the version in the record' do
        base_course_custom_content_version.publish_latest!(admin_user)
        expect(CustomContentVersion.last.id).to eq(
          base_course_custom_content_version.custom_content_version.id,
        )
      end
    end

    context 'assignment deleted in Canvas' do
      before(:each) do
        allow(canvas_client)
          .to receive(:get_assignment)
          .with(course.canvas_course_id, base_course_custom_content_version.canvas_assignment_id)
          .and_raise(RestClient::NotFound)
      end

      it 'does not create a new version' do
        expect {
          base_course_custom_content_version.publish_latest!(admin_user) rescue nil
        }.not_to change(CustomContentVersion, :count)
      end

      it 'does not update the version in the record' do
        version = base_course_custom_content_version.custom_content_version
        base_course_custom_content_version.publish_latest!(admin_user) rescue nil
        expect(version).to eq(base_course_custom_content_version.custom_content_version)
      end
    end
  end

  describe '#remove!' do
    let!(:canvas_client) { double(CanvasAPI) }

    context 'valid' do
      shared_examples 'record and assignment are deleted' do
        scenario 'deletes the record' do
          expect {
            base_course_custom_content_version.remove!
          }.to change(BaseCourseCustomContentVersion, :count).by(-1)
        end

        scenario 'deletes the Canvas assignment' do
          base_course_custom_content_version.remove!
          expect(canvas_client)
            .to have_received(:delete_assignment)
            .with(course.canvas_course_id, base_course_custom_content_version.canvas_assignment_id)
            .once
        end
      end

      context 'the assignment does not exist in Canvas' do
        before(:each) do
          allow(CanvasAPI).to receive(:client).and_return(canvas_client)
          allow(canvas_client)
            .to receive(:delete_assignment)
            .with(course.canvas_course_id, base_course_custom_content_version.canvas_assignment_id)
            .and_raise(RestClient::NotFound)
        end

        it_behaves_like 'record and assignment are deleted'
      end

      context 'the assignment exists in Canvas' do
        before(:each) do
          canvas_assignment = {
            'assignment': {
              'id': base_course_custom_content_version.canvas_assignment_id
            },
          }
          allow(CanvasAPI).to receive(:client).and_return(canvas_client)
          allow(canvas_client)
            .to receive(:delete_assignment)
            .with(course.canvas_course_id, base_course_custom_content_version.canvas_assignment_id)
            .and_return(canvas_assignment)
        end

        it_behaves_like 'record and assignment are deleted'
      end
    end
  
    context 'invalid' do
      context 'there are already submissions for the assignment' do
        before(:each) do
          allow(base_course_custom_content_version)
            .to receive(:destroy!)
            .and_raise(ActiveRecord::InvalidForeignKey)

          allow(CanvasAPI).to receive(:client).and_return(canvas_client)
          allow(canvas_client).to receive(:delete_assignment)
        end

        it 'does not not delete the record' do
          expect{
            base_course_custom_content_version.remove! rescue nil
          }.not_to change(BaseCourseCustomContentVersion, :count)
        end

        it 'does not try to delete the assignment in Canvas' do
          base_course_custom_content_version.remove! rescue nil
          expect(canvas_client).not_to have_received(:delete_assignment)
        end
      end
    end
  end
end
