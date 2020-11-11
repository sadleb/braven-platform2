require 'rails_helper'

RSpec.describe BaseCourseCustomContentVersion, type: :model do

  let(:course) { create :course_with_canvas_id }
  let(:project) { create :project }
  let(:project_version) { create :project_version, custom_content: project }
  let(:base_course_custom_content_version) { create :base_course_custom_content_version, base_course: course, custom_content_version: project_version } 

  describe '#valid?' do
    subject { base_course_custom_content_version }

    context 'when valid attributes' do
      it { is_expected.to be_valid }
    end
  end

  describe '#publish!' do

    let(:canvas_client) { double(CanvasAPI) }
    let(:admin_user) { create :admin_user }
    let(:canvas_assignment_id) { 123 }
    let(:canvas_assignment) { { 'id' => canvas_assignment_id } }
    let(:rubric_id) { nil }

    before(:each) do
      # Stubs out all the API calls, you can override them in your own context
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:create_lti_assignment).and_return(canvas_assignment)
      allow(canvas_client).to receive(:update_assignment_lti_launch_url)
      allow(canvas_client).to receive(:add_rubric_to_assignment)
      allow(canvas_client).to receive(:delete_assignment)
    end

    context 'valid' do
      shared_examples 'updates the DB' do
        scenario 'creates a new version' do
          bcccv = nil
          expect {
            bcccv = BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id)
          }.to change(CustomContentVersion, :count).by(1)
          expect(bcccv.custom_content_version).to eq(project.last_version)
        end

        scenario 'creates a new record' do
          bcccv = nil
          expect {
            bcccv = BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id)
          }.to change(BaseCourseCustomContentVersion, :count).by(1)
          expect(bcccv.base_course).to eq(course)
          expect(bcccv.custom_content_version).to eq(project.last_version)
        end

        scenario 'updates the Canvas assignment ID' do
          bcccv = BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id)
          expect(bcccv.canvas_assignment_id).to eq(canvas_assignment_id)
        end
      end

      shared_examples 'updates Canvas' do
        scenario 'creates a new Canvas assignment' do
          bcccv = BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id)
          expect(canvas_client)
            .to have_received(:create_lti_assignment)
            .with(course.canvas_course_id, bcccv.custom_content_version.title)
            .once
        end

        scenario 'updates the submission URL' do
          bcccv = BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id)
          expect(canvas_client)
            .to have_received(:update_assignment_lti_launch_url)
            .with(course.canvas_course_id, bcccv.canvas_assignment_id, bcccv.new_submission_url)
            .once
        end
      end

      context 'without rubric' do
        it_behaves_like 'updates the DB'
        it_behaves_like 'updates Canvas'

        it 'does not add a rubric' do
          BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id)
          expect(canvas_client).not_to have_received(:add_rubric_to_assignment)
        end
      end

      context 'with rubric' do
        let(:rubric_id) { 456 }

        it_behaves_like 'updates the DB'
        it_behaves_like 'updates Canvas'

        it 'adds a rubric' do
          BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id)
          expect(canvas_client)
            .to have_received(:add_rubric_to_assignment)
            .with(course.canvas_course_id, canvas_assignment_id, rubric_id)
            .once
        end
      end
    end

    context 'invalid' do
      shared_examples 'reverts DB changes' do
        scenario 'does not create a new version' do
          expect {
            BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id) rescue nil
          }.not_to change(CustomContentVersion, :count)
        end

        scenario 'does not create a new record' do
          expect {
            BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id) rescue nil
          }.not_to change(BaseCourseCustomContentVersion, :count)
        end
      end

      shared_examples 'reverts Canvas changes' do
        scenario 'deletes the Canvas assignment' do
          BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id) rescue nil
          expect(canvas_client)
            .to have_received(:delete_assignment)
            .with(canvas_assignment_id)
            .once
        end
      end

      context 'Canvas assignment creation error' do
        let(:rubric_id) { 111 }

        before(:each) do
          allow(canvas_client)
            .to receive(:create_lti_assignment)
            .and_raise(RestClient::BadRequest)
        end

        it_behaves_like 'reverts DB changes'

        it 'does not add the rubric' do
          BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id) rescue nil
          expect(canvas_client).not_to have_received(:add_rubric_to_assignment)
        end
      end

      context 'missing Canvas assignment ID' do
        let(:canvas_assignment_id) { nil }

        it_behaves_like 'reverts DB changes'
        it_behaves_like 'reverts Canvas changes'

        it 'throws a validation error' do
          expect {
            BaseCourseCustomContentVersion.publish!(course, project, admin_user, rubric_id)
          }.to raise_error(ActiveRecord::NotNullViolation)
        end
      end

      context 'error adding rubric to assignment in Canvas' do
        let(:rubric_id) { 789 }

        before(:each) do
          allow(canvas_client)
            .to receive(:create_lti_assignment)
            .and_return(canvas_assignment)
          allow(canvas_client)
            .to receive(:add_rubric_to_assignment)
            .with(course.canvas_course_id, canvas_assignment_id, rubric_id)
            .and_raise(RestClient::BadRequest)
        end

        it_behaves_like 'reverts DB changes'
        it_behaves_like 'reverts Canvas changes'
      end
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
