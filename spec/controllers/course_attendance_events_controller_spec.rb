require 'rails_helper'
require 'canvas_api'

RSpec.describe CourseAttendanceEventsController, type: :controller do
  render_views

  let(:canvas_client) { double(CanvasAPI) }
  let!(:admin_user) { create :admin_user }
  let(:course) { create :course }
  let(:attendance_event) { create :attendance_event }
  let!(:course_attendance_event) { create(
    :course_attendance_event,
    course: course,
    attendance_event: attendance_event,
  ) }

  before do
    sign_in admin_user
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new, params: { course_id: course.id }
      expect(response).to be_successful
    end

    it 'excludes attendance events that have already been added to the course' do
      unpublished_attendance_event = AttendanceEvent.create!(title: 'New Event')
      get :new, params: { course_id: course.id }
      expect(response.body).to match /<option value="#{unpublished_attendance_event.id}">#{unpublished_attendance_event.title}<\/option>/
      expect(response.body).not_to match /<option.*>#{course_attendance_event.attendance_event.title}<\/option>/
    end
  end

  describe 'POST #publish' do
    let(:canvas_assignment_id) { 1234 }

    subject {
      post :publish, params: {
        course_id: course.id,
        attendance_event_id: attendance_event.id,
      }
    }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client)
        .to receive(:create_lti_assignment)
        .and_return({ 'id' => canvas_assignment_id })
      allow(canvas_client).to receive(:update_assignment_lti_launch_url)
    end

    it 'adds a new join table entry' do
      expect { subject }.to change(CourseAttendanceEvent, :count).by(1)
      expect(CourseAttendanceEvent.last.course).to eq(course)
      expect(CourseAttendanceEvent.last.attendance_event).to eq(attendance_event)
    end

    it 'adds the module to the course' do
      subject
      expect(course.attendance_events).to include(attendance_event)
    end

    it 'creates a new Canvas assignment' do
      subject
      launch_url = launch_attendance_event_submissions_url(protocol: 'https')
      expect(canvas_client)
        .to have_received(:create_lti_assignment)
        .with(course.canvas_course_id, attendance_event.title)
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
    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:delete_assignment)
    end

    subject {
      delete :unpublish, params: {
        course_id: course.id,
        id: course_attendance_event.id,
      }
    }

    it 'deletes the join table entry' do
      expect { subject }.to change(CourseAttendanceEvent, :count).by(-1)
    end

    it 'deletes the Canvas assignment' do
      subject
      expect(canvas_client)
        .to have_received(:delete_assignment)
        .with(course.canvas_course_id, course_attendance_event.canvas_assignment_id)
        .once
    end

    it 'does not delete the attendance event' do
      expect { subject }.not_to change { AttendanceEvent.count }
    end

    it 'does not delete the course' do
      expect { subject }.not_to change { Course.count }
    end

    it 'redirects to course edit page' do
      subject
      expect(response).to redirect_to edit_course_path(course)
    end
  end
end
