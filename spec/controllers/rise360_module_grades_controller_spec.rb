require 'rails_helper'

RSpec.describe Rise360ModuleGradesController, type: :controller do
  render_views

  let(:state) { LtiLaunchController.generate_state }
  let(:course) { create :course }
  let(:course_rise360_module_version) {
    create( :course_rise360_module_version, course: course)
  }
  let(:total_quiz_questions) { course_rise360_module_version.rise360_module_version.quiz_questions }
  let(:canvas_assignment_id) { course_rise360_module_version.canvas_assignment_id }
  let(:user_with_grade) { create :fellow_user, canvas_user_id: '987432' }
  let(:user_viewing) { user_with_grade }
  let(:rise360_module_grade) {
    create :rise360_module_grade, user: user_with_grade, course_rise360_module_version: course_rise360_module_version
  }
  let(:canvas_api_user_id) { 9954321 }
  let(:due_date) { (Time.now + 1.week).utc.iso8601 } # future due date
  let(:graded_at) { (Time.now - 1.day).utc.iso8601 }
  let(:submission_score) { 0.0 }
  let(:grader_id) { canvas_api_user_id }
  let(:canvas_submission) {
    create :canvas_submission,
      cached_due_date: due_date,
      grader_id: grader_id,
      graded_at: graded_at,
      score: submission_score
  }
  let(:canvas_client) { double(CanvasAPI) }
  let(:compute_service) { double(ComputeRise360ModuleGrade) }

  let(:total_grade) { 0 }
  let(:engagement_grade) { 0 }
  let(:quiz_grade) { 0 }
  let(:on_time_grade) { 0 }
  let(:completed_at) { nil }
  let(:grade_breakdown) {
     ComputeRise360ModuleGrade::ComputedGradeBreakdown.new(
       total_grade,
       engagement_grade,
       quiz_grade,
       on_time_grade,
       completed_at
     )
  }

  let!(:lti_launch) {
    create(:lti_launch_assignment,
      state: state,
      canvas_user_id: user_viewing.canvas_user_id,
      canvas_course_id: course.canvas_course_id,
      canvas_assignment_id: course_rise360_module_version.canvas_assignment_id)
  }

  before do
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(canvas_client).to receive(:update_grade)
    allow(canvas_client).to receive(:api_user_id).and_return(canvas_api_user_id)
    allow(canvas_client).to receive(:get_latest_submission)
      .with(course.canvas_course_id, canvas_assignment_id, user_with_grade.canvas_user_id)
      .and_return(canvas_submission)
    allow(ComputeRise360ModuleGrade).to receive(:new).and_return(compute_service)
    allow(compute_service).to receive(:run).and_return(grade_breakdown)

    sign_in user_viewing
  end

  describe 'GET #show' do
    subject(:get_show) do
      get :show, params: {:id => rise360_module_grade.id, :state => state}
    end

    it 'returns a success response' do
      get_show
      expect(response).to be_successful
    end

    # Note: this is just a couple example grade breakdowns focused on testing the display,
    # NOT the math. The grade breakdown math is tested in compute_rise360_module_grade_spec
    context 'when showing the grade breakdown' do
      it 'shows the intro' do
        get_show
        expect(response.body).to match(/Here is how your Module grade breaks down/)
      end

      context 'when no progress' do
        let(:total_grade) { 0 }
        let(:engagement_grade) { 0 }
        let(:quiz_grade) { 0 }
        let(:on_time_grade) { 0 }
        let(:completed_at) { nil }

        it 'shows engagement score as 0.0 / 4.0 and 0% progress' do
          get_show
          expect(response.body).to match(/Engagement:.*#{Regexp.escape('0.0 / 4.0')}/m)
          expect(response.body).to match(/You completed 0% of the Module/)
        end

        it 'shows the mastery score as 0.0 / 4.0 and 0% of the total questions correct' do
          get_show
          expect(response.body).to match(/Mastery quizzes:.*#{Regexp.escape('0.0 / 4.0')}/m)
          expect(response.body).to match(/You got 0% of the #{total_quiz_questions} mastery questions correct./)
        end

        it 'shows on time credit as 0.0 / 2.0 and a message about how to get credit' do
          get_show
          expect(response.body).to match(/On Time:.*#{Regexp.escape('0.0 / 2.0')}/m)
          expect(response.body).to match(/Awarded when you complete 100% of the Module before the due date./)
        end

        it 'shows the total grade as 0.0 / 10.0' do
          get_show
          expect(response.body).to match(/Total Grade:.*#{Regexp.escape('0.0 / 10.0')}/m)
        end
      end

      context 'when some progress' do
        let(:total_grade) { (engagement_grade * 0.4) + (quiz_grade * 0.4) + (on_time_grade * 0.2) }
        let(:engagement_grade) { 50 }
        let(:quiz_grade) { 50 }
        let(:on_time_grade) { 0 }
        let(:completed_at) { nil }

        it 'shows engagement score as 2.0 / 4.0 and 50% progress' do
          get_show
          expect(response.body).to match(/Engagement:.*#{Regexp.escape('2.0 / 4.0')}/m)
          expect(response.body).to match(/You completed 50% of the Module/)
        end

        it 'shows the mastery score as 2.0 / 4.0 and 50% of the total questions correct' do
          get_show
          expect(response.body).to match(/Mastery quizzes:.*#{Regexp.escape('2.0 / 4.0')}/m)
          expect(response.body).to match(/You got 50% of the #{total_quiz_questions} mastery questions correct./)
        end

        it 'shows on time credit as 0.0 / 2.0 and a message about how to get credit' do
          get_show
          expect(response.body).to match(/On Time:.*#{Regexp.escape('0.0 / 2.0')}/m)
          expect(response.body).to match(/Awarded when you complete 100% of the Module before the due date./)
        end

        it 'shows the total grade as 4.0 / 10.0' do
          get_show
          expect(response.body).to match(/Total Grade:.*#{Regexp.escape('4.0 / 10.0')}/m)
        end
      end

      context 'when completed_at on time' do
        let(:total_grade) { (engagement_grade * 0.4) + (quiz_grade * 0.4) + (on_time_grade * 0.2) }
        let(:engagement_grade) { 100 }
        let(:quiz_grade) { 75 }
        let(:on_time_grade) { 100 }
        let(:completed_at) { (Time.now - 1.week).utc.iso8601 }

        it 'shows engagement score as 4.0 / 4.0 and 100% progress' do
          get_show
          expect(response.body).to match(/Engagement:.*#{Regexp.escape('4.0 / 4.0')}/m)
          expect(response.body).to match(/You completed 100% of the Module/)
        end

        it 'shows the mastery score as 3.0 / 4.0 and 75% of the total questions correct' do
          get_show
          expect(response.body).to match(/Mastery quizzes:.*#{Regexp.escape('3.0 / 4.0')}/m)
          expect(response.body).to match(/You got 75% of the #{total_quiz_questions} mastery questions correct./)
        end

        it 'shows on time credit as 2.0 / 2.0 and a message about why they got credit' do
          get_show
          expect(response.body).to match(/On Time:.*#{Regexp.escape('2.0 / 2.0')}/m)
          expect(response.body).to match(/You completed the Module before the due date/)
        end

        it 'shows the total grade as 9.0 / 10.0' do
          get_show
          expect(response.body).to match(/Total Grade:.*#{Regexp.escape('9.0 / 10.0')}/m)
        end
      end

      context 'when completed_at late' do
        let(:total_grade) { (engagement_grade * 0.4) + (quiz_grade * 0.4) + (on_time_grade * 0.2) }
        let(:engagement_grade) { 100 }
        let(:quiz_grade) { 97 }
        let(:on_time_grade) { 0 }
        let(:completed_at) { Time.now.utc.iso8601 }

        it 'shows engagement score as 4.0 / 4.0 and 100% progress' do
          get_show
          expect(response.body).to match(/Engagement:.*#{Regexp.escape('4.0 / 4.0')}/m)
          expect(response.body).to match(/You completed 100% of the Module/)
        end

        # Score is actually 3.88 rounded up
        it 'shows the mastery score as 3.9 / 4.0 and 97% of the total questions correct' do
          get_show
          expect(response.body).to match(/Mastery quizzes:.*#{Regexp.escape('3.9 / 4.0')}/m)
          expect(response.body).to match(/You got 97% of the #{total_quiz_questions} mastery questions correct./)
        end

        it 'shows on time credit as 0.0 / 2.0 and a message about why they did not get credit with the completed_at time' do
          get_show
          expect(response.body).to match(/On Time:.*#{Regexp.escape('0.0 / 2.0')}/m)
          expect(response.body).to match(/Awarded when you complete 100% of the Module before the due date.*You completed this module after the due date, at .*#{completed_at}/m)
        end

        it 'shows the total grade as 7.9 / 10.0' do
          get_show
          expect(response.body).to match(/Total Grade:.*#{Regexp.escape('7.9 / 10.0')}/m)
        end
      end

    end

    it 'links to the Module itself' do
      get_show
      expect(response.body).to match /<a href="#{Regexp.escape(course_rise360_module_version.canvas_url)}" target="_parent"/
    end

    shared_examples 'up to date' do
      # Make the Canvas submission score match the computed total_grade
      let(:submission_score) { 5.0 }
      let(:total_grade) { 50 }

      it 'doesnt show a message about the grade being out-of-date' do
        get_show
        expect(response.body).not_to match(/grade was just updated/)
      end
    end

    it_behaves_like 'up to date'

    context 'when grade is not up to date' do
      let(:submission_score) { 4.0 } # must be lower than computed total_grade to be out of date
      let(:total_grade) { 50 }

      it 'shows a message about the grade being out-of-date' do
        get_show
        expect(response.body).to match(/grade was just updated/)
      end
    end

    context 'when manually graded' do
      let(:submission_score) { 6.0 } # Make sure this is higher than computed total_grade
      let(:total_grade) { 50 }
      let(:manual_grader_id) { canvas_api_user_id + 1 } # just needs to be different from the api user id
      let(:manual_grader_name) { 'Test GraderName' }
      let(:grader_id) { manual_grader_id }

      before(:each) do
        allow(canvas_client).to receive(:show_user_details).and_return({'name' => manual_grader_name})
      end

      # Make sure it doesn't accidentally show both messages. If it's manually graded to be higher than the computed grade, it's up to date.
      it_behaves_like 'up to date'

      it 'shows a message about it being manually graded' do
        get_show
        expect(response.body).to match(/has been manually given a grade of.*#{submission_score} \/ #{Rise360Module::POINTS_POSSIBLE}.*by.*#{manual_grader_name}/)
      end
    end
  end

end

