require 'rails_helper'
require 'canvas_api'
require 'rise360_util'
require 'uri'

RSpec.describe CourseRise360ModuleVersionsController, type: :controller do
  render_views

  let(:canvas_client) { double(CanvasAPI) }
  let!(:admin_user) { create :admin_user }
  let(:course) { create :course }
  let(:rise360_module_version) { create :rise360_module_version }
  let!(:course_rise360_module_version) { create(
    :course_rise360_module_version,
    course: course,
    rise360_module_version: rise360_module_version,
  ) }

  before do
    sign_in admin_user
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new, params: { course_id: course.id }
      expect(response).to be_successful
    end

    it 'excludes modules that have already been added to the course' do
      unpublished_module = Rise360Module.create!(name: 'New Module')
      get :new, params: { course_id: course.id }
      expect(response.body).to match /<option value="#{unpublished_module.id}">#{unpublished_module.name}<\/option>/
      expect(response.body).not_to match /<option.*>#{rise360_module_version.rise360_module.name}<\/option>/
    end
  end

  describe 'PUT #publish_latest' do
    let(:new_rise360_module_name) { 'UPDATED! Rise360 Module Name' }
    let(:other_params) { {} }

    subject {
      # Update the Rise360Module first
      rise360_module_version.rise360_module.update!(name: new_rise360_module_name)
      put :publish_latest, params: {
        course_id: course.id,
        id: course_rise360_module_version.id,
      }.merge(other_params)
    }

    context 'Canvas API exception' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:update_assignment_name)
          .and_raise(RestClient::BadRequest)
        allow(canvas_client)
          .to receive(:update_assignment_lti_launch_url)
          .and_raise(RestClient::BadRequest)
      end

      it 'does not change the join table entry' do
        existing_module_version = course_rise360_module_version
        expect { subject rescue nil }.not_to change(CourseRise360ModuleVersion, :count)
        expect(CourseRise360ModuleVersion.last).to eq(existing_module_version)
      end
    end

    context 'Canvas assignment found' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client).to receive(:update_assignment_name)
        allow(canvas_client).to receive(:update_assignment_lti_launch_url)
      end

      it 'creates a new module version' do
        expect { subject }.to change(Rise360ModuleVersion, :count).by(1)
      end

      it 'updates the existing join table entry' do
        expect { subject }.not_to change { CourseRise360ModuleVersion.count }
        expect(course_rise360_module_version.reload.rise360_module_version).to eq(Rise360ModuleVersion.last)
      end

      it 'updates the Canvas assignment name' do
        subject
        expect(canvas_client)
          .to have_received(:update_assignment_name)
          .with(
            course.canvas_course_id,
            course_rise360_module_version.canvas_assignment_id,
            new_rise360_module_name,
          )
          .once
      end

      it 'updates the Canvas assignment LTI launch URL' do
        subject
        expect(canvas_client)
          .to have_received(:update_assignment_lti_launch_url)
          .with(
            course.canvas_course_id,
            course_rise360_module_version.canvas_assignment_id,
            rise360_module_version_url(
              Rise360ModuleVersion.last,
              protocol: 'https',
            ),
          )
          .once
      end

      it 'deletes all States attached to old versions' do
        # Matching.
        create(:rise360_module_state,
          state_id: 'bookmark',
          canvas_assignment_id: course_rise360_module_version.canvas_assignment_id
        )
        # Non-matching.
        create(:rise360_module_state,
          state_id: 'bookmark',
          canvas_assignment_id: course_rise360_module_version.canvas_assignment_id + 1
        )
        expect(Rise360ModuleState.count).to eq(2)

        expect {
          subject
        }.to change(Rise360ModuleState, :count).by (-1)
      end

      it 'deletes all related Interactions' do
        create(:progressed_module_interaction, canvas_assignment_id: course_rise360_module_version.canvas_assignment_id)
        create(:answered_module_interaction, canvas_assignment_id: course_rise360_module_version.canvas_assignment_id)
        create(:progressed_module_interaction, canvas_assignment_id: course_rise360_module_version.canvas_assignment_id + 1)
        expect { subject }.to change(Rise360ModuleInteraction, :count).by(-2)
      end

      it 'redirects to course edit page' do
        subject
        expect(response).to redirect_to edit_course_path(course)
      end

      context 'with student data' do
        let!(:rise360_module_grade) { create(:rise360_module_grade, course_rise360_module_version: course_rise360_module_version) }

        it 'redirects to before_publish_latest page to show a message' do
          subject
          expect(course_rise360_module_version.has_student_data?).to eq(true)
          expect(response).to redirect_to before_publish_latest_course_course_rise360_module_version_path
        end

        context 'when force delete param is sent' do
          let(:other_params) { {:force_delete_student_data => true} }

          it 'purges student data' do
            expect{ subject }.to change(Rise360ModuleGrade, :count).by(-1)
          end

          it 'publishes latest' do
            expect { subject }.to change(Rise360ModuleVersion, :count).by(1)
          end
        end
      end
    end
  end

  describe 'GET #before_publish_latest' do
    subject {
      get :before_publish_latest, params: {
        course_id: course.id,
        id: course_rise360_module_version.id,
      }
    }

    it 'shows a message warning them that student data will be purged' do
      subject
      expect(response.body).to include('DANGER: Fellows have started working on this Module')
    end

    it 'adds the hidden force_delete_student_data param to the form' do
      subject
      expect(response.body).to include('<input value="true" type="hidden" name="force_delete_student_data" id="force_delete_student_data" />')
    end
  end

  describe 'POST #publish' do
    let(:canvas_assignment_id) { 1234 }
    let(:launch_path) { '/lessons/somekey/index.html' }
    let(:rise360_module) { create :rise360_module_with_zipfile }

    subject {
      post :publish, params: {
        course_id: course.id,
        rise360_module_id: rise360_module.id,
      }
    }

    before(:each) do
      allow(Rise360Util).to receive(:launch_path).and_return(launch_path)
      allow(Rise360Util).to receive(:publish).and_return(launch_path)
      allow(Rise360Util).to receive(:update_metadata!).and_return(rise360_module)

      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client)
        .to receive(:create_lti_assignment)
        .and_return({ 'id' => canvas_assignment_id })
      allow(canvas_client).to receive(:update_assignment_lti_launch_url)
    end

    it 'adds a new join table entry' do
      expect { subject }.to change(CourseRise360ModuleVersion, :count).by(1)
      course_rise360_module_version = CourseRise360ModuleVersion.last
      module_version = Rise360ModuleVersion.last
      expect(course_rise360_module_version.course).to eq(course)
      expect(course_rise360_module_version.rise360_module_version).to eq(module_version)
    end

    it 'creates a new module version' do
      expect { subject }.to change(Rise360ModuleVersion, :count).by(1)
    end

    it 'adds the module to the course' do
      subject
      expect(course.rise360_modules).to include(CourseRise360ModuleVersion.last.rise360_module_version.rise360_module)
    end

    it 'creates a new Canvas assignment' do
      subject
      launch_url = rise360_module_version_url(
        Rise360ModuleVersion.last,
        protocol: 'https',
      )
      expect(canvas_client)
        .to have_received(:create_lti_assignment)
        .with(course.canvas_course_id, rise360_module.name)
        .once
      expect(canvas_client)
        .to have_received(:update_assignment_lti_launch_url)
        .with(course.canvas_course_id, canvas_assignment_id, launch_url)
        .once
    end

    it 'redirects to course edit page' do
      subject
      expect(response).to redirect_to edit_course_path(course)
    end
  end

  describe 'DELETE #unpublish' do
    let(:other_params) { {} }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client)
        .to receive(:delete_assignment)
    end

    subject {
      delete :unpublish, params: {
        course_id: course.id,
        id: course_rise360_module_version.id,
      }.merge(other_params)
    }

    it 'deletes the join table entry' do
      expect { subject }.to change(CourseRise360ModuleVersion, :count).by(-1)
    end

    it 'deletes all related Interactions' do
      create(:progressed_module_interaction, canvas_assignment_id: course_rise360_module_version.canvas_assignment_id)
      create(:answered_module_interaction, canvas_assignment_id: course_rise360_module_version.canvas_assignment_id)
      create(:progressed_module_interaction, canvas_assignment_id: course_rise360_module_version.canvas_assignment_id + 1)
      expect { subject }.to change(Rise360ModuleInteraction, :count).by(-2)
    end

    it 'deletes all States attached' do
      # Matching.
      create(:rise360_module_state,
        state_id: 'bookmark',
        canvas_assignment_id: course_rise360_module_version.canvas_assignment_id
      )
      # Non-matching.
      create(:rise360_module_state,
        state_id: 'bookmark',
        canvas_assignment_id: course_rise360_module_version.canvas_assignment_id + 1
      )
      expect(Rise360ModuleState.count).to eq(2)

      expect {
        subject
      }.to change(Rise360ModuleState, :count).by (-1)
    end

    it 'deletes the Canvas assignment' do
      subject
      expect(canvas_client)
        .to have_received(:delete_assignment)
        .with(course.canvas_course_id, course_rise360_module_version.canvas_assignment_id)
        .once
    end

    it 'does not delete the module version' do
      expect { subject }.not_to change { Rise360ModuleVersion.count }
    end

    it 'does not delete the course' do
      expect { subject }.not_to change { Course.count }
    end

    it 'redirects to course edit page' do
      subject
      expect(response).to redirect_to edit_course_path(course)
    end

    context 'with student data' do
      let!(:rise360_module_grade) { create(:rise360_module_grade, course_rise360_module_version: course_rise360_module_version) }

      it 'redirects to before_unpublish to show a message' do
        subject
        expect(course_rise360_module_version.has_student_data?).to eq(true)
        expect(response).to redirect_to before_unpublish_course_course_rise360_module_version_path
      end

      context 'when force delete param is sent' do
        let(:other_params) { {:force_delete_student_data => true} }

        it 'purges student data' do
          expect{ subject }.to change(Rise360ModuleGrade, :count).by(-1)
        end

        it 'deletes the join table entry' do
          expect { subject }.to change(CourseRise360ModuleVersion, :count).by(-1)
        end
      end
    end
  end

  describe 'GET #before_unpublish' do
    subject {
      get :before_unpublish, params: {
        course_id: course.id,
        id: course_rise360_module_version.id,
      }
    }

    it 'shows a message warning them that student data will be purged' do
      subject
      expect(response.body).to include('DANGER: Fellows have started working on this Module')
    end

    it 'adds the hidden force_delete_student_data param to the form' do
      subject
      expect(response.body).to include('<input value="true" type="hidden" name="force_delete_student_data" id="force_delete_student_data" />')
    end
  end
end
