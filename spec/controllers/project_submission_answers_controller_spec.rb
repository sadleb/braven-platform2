require 'rails_helper'

RSpec.describe ProjectSubmissionAnswersController, type: :controller do
  render_views

  let(:course_project_version) { create :course_project_version }
  let(:section) { create :section, course: course_project_version.course }
  let(:user_who_submitted) { create :fellow_user, section: section }
  let(:user_viewing_submission) { user_who_submitted }
  let(:project_submission) {
    create :project_submission, user: user_who_submitted, course_project_version: course_project_version
  }
  let(:project_submission_answers) { [
    create(:project_submission_answer, project_submission: project_submission),
    create(:project_submission_answer, project_submission: project_submission),
  ] }
  let(:lti_launch) {
    create :lti_launch_assignment, canvas_user_id: user_viewing_submission.canvas_user_id
  }

  describe 'GET #index' do

    before(:each) do
      allow(LtiLaunch).to receive(:current).and_return(lti_launch)
      project_submission_answers
      get(
        :index,
        params: {
          project_submission_id: project_submission.id,
          state: lti_launch.state,
        },
        format: :json,
      )
    end

    context "as a Fellow" do
      it 'returns a success response' do
        expect(response).to be_successful
      end

      it 'shows the correct content' do
        parsed_body = JSON.parse(response.body)
        expect(parsed_body.count).to eq(2)
        expect(parsed_body[0]['input_name']).to eq(project_submission_answers[0].input_name)
        expect(parsed_body[1]['input_value']).to eq(project_submission_answers[1].input_value)
      end
    end

    context "as a TA" do
      let(:ta_user) { create :ta_user, section: section }
      let(:user_viewing_submission) { ta_user }

      it 'returns a success response' do
        expect(response).to be_successful
      end

      it 'shows the correct content' do
        parsed_body = JSON.parse(response.body)
        expect(parsed_body.count).to eq(2)
        expect(parsed_body[0]['input_name']).to eq(project_submission_answers[0].input_name)
        expect(parsed_body[1]['input_value']).to eq(project_submission_answers[1].input_value)
      end
    end

  end # 'GET #index'

  describe 'POST #create' do

    before(:each) do
      allow(LtiLaunch).to receive(:current).and_return(lti_launch)
      post(
        :create,
        params: {
          project_submission_id: project_submission.id,
          state: lti_launch.state,
          project_submission_answer: {
            input_name: 'test_input',
            input_value: 'test value',
          },
        },
        format: :json,
      )
    end

    context "as a Fellow" do
      it 'returns a success response' do
        expect(response).to be_successful
      end

      it 'creates a project_submission_answer' do
        new_answer = project_submission.answers.last
        expect(project_submission.answers.count).to eq(1)
        expect(new_answer.input_name).to eq('test_input')
        expect(new_answer.input_value).to eq('test value')
      end
    end

  end # 'POST #create'

end