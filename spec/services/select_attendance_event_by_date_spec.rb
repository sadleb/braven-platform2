require 'rails_helper'
require 'select_attendance_event_by_date'
require 'canvas_api'

RSpec.describe SelectAttendanceEventByDate do
  let(:course) { create :course }
  let(:section) { create :section, course: course }
  let(:ta_user) { create :ta_user, accelerator_section: section }
  let(:fellow_user) { create :fellow_user, section: section }
  let(:date) { Time.now.utc }
  let(:assignment_overrides) { [] }
  let(:canvas_client) { double(CanvasAPI) }

  describe '#run' do

    subject(:select_attendance_event_service) do
      SelectAttendanceEventByDate.new(course, ta_user, section, date)
    end

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:get_assignment_overrides_for_section)
        .and_return(assignment_overrides)
    end

    context 'no attendance events' do
      let(:assignment_overrides) { [] }
      it 'returns nil' do
        cav = select_attendance_event_service.run()
        expect(cav).to eq(nil)
        expect(canvas_client).not_to have_received(:get_assignment_overrides_for_section)
      end
    end

    context 'one attendance event' do
      let!(:canvas_assignment_override) { create(
        :canvas_assignment_override,
        due_at: due_at
      ) }
      let!(:course_attendance_event) { create(
        :course_attendance_event,
        course: course,
        canvas_assignment_id: canvas_assignment_override['assignment_id'],
      ) }
      let(:assignment_overrides) { [canvas_assignment_override] }

      context 'no due date set' do
        let(:due_at) { nil }
        it 'returns nil' do
          cav = select_attendance_event_service.run()
          expect(cav).to eq(nil)
        end
      end

      context '1 day before date' do
        let(:due_at) { date.yesterday.iso8601 }
        it 'returns the event' do
          cav = select_attendance_event_service.run()
          expect(cav).to eq(course_attendance_event)
        end
      end

      context '2 days before date' do
        let(:due_at) { (date - 2.days).iso8601 }
        it 'returns the event' do
          cav = select_attendance_event_service.run()
          expect(cav).to eq(course_attendance_event)
        end
      end

      context 'on date' do
        let(:due_at) { date.middle_of_day.iso8601 }
        it 'returns the event' do
          cav = select_attendance_event_service.run()
          expect(cav).to eq(course_attendance_event)
        end
      end

      context 'after date' do
        let(:due_at) { date.tomorrow.iso8601 }
        it 'returns the event' do
          cav = select_attendance_event_service.run()
          expect(cav).to eq(course_attendance_event)
        end
      end
    end

    context 'multiple attendance events' do
      let!(:today) { Time.now.utc }
      let(:day_after_tomorrow_date) { today.tomorrow.tomorrow }

      let!(:canvas_assignment_override_yesterday) { create(
        :canvas_assignment_override,
        due_at: today.yesterday.iso8601,
      ) }
      let!(:course_attendance_event_yesterday) { create(
        :course_attendance_event,
        course: course,
        canvas_assignment_id: canvas_assignment_override_yesterday['assignment_id'],
      ) }

      let!(:canvas_assignment_override_day_after_tomorrow) { create(
        :canvas_assignment_override,
        due_at: day_after_tomorrow_date.iso8601,
      ) }
      let!(:course_attendance_event_day_after_tomorrow){ create(
        :course_attendance_event,
        course: course,
        canvas_assignment_id: canvas_assignment_override_day_after_tomorrow['assignment_id'],
      ) }
      let!(:assignment_overrides) { [canvas_assignment_override_yesterday, canvas_assignment_override_day_after_tomorrow] }

      it 'calls the Canvas API with the correct parameters' do
        select_attendance_event_service.run()
        expect(canvas_client).to have_received(:get_assignment_overrides_for_section)
          .with(course.canvas_course_id, section.canvas_section_id,
               [
                 course_attendance_event_yesterday.canvas_assignment_id,
                 course_attendance_event_day_after_tomorrow.canvas_assignment_id,
               ]
          )
      end

      context 'with non-UTC timezone' do
        let!(:date) { Time.now.getlocal("-06:00") }
        it 'raises an error' do
          expect{ select_attendance_event_service.run() }.to raise_error(
            SelectAttendanceEventByDate::SelectAttendanceEventByDateError
          )
        end
      end

      context 'viewed before first event' do
        let(:date) { today.yesterday.yesterday }
        it 'returns yesterdays event' do
          cav = select_attendance_event_service.run()
          expect(cav).to eq(course_attendance_event_yesterday)
        end
      end

      # The event doesnt switch over to the next one until midnight on the same day of the event
      # which is 2 days from now
      context 'viewing today' do
        let(:date) { today }
        it 'returns yesterdays event' do
          cav = select_attendance_event_service.run()
          expect(cav).to eq(course_attendance_event_yesterday)
        end
      end

      context 'viewing yesterday' do
        let(:date) { today.yesterday }
        it 'returns yesterdays event' do
          cav = select_attendance_event_service.run()
          expect(cav).to eq(course_attendance_event_yesterday)
        end
      end

      context 'viewing tomorrow' do
        let(:date) { today.tomorrow }
        it 'returns yesterdays event' do
          # Just making sure we didn't mess up the setup. It's the day of the week we care about
          # when switching over to view the next event. It should happen at midnight.
          expect(date.day).not_to eq(day_after_tomorrow_date.day)
          cav = select_attendance_event_service.run()
          expect(cav).to eq(course_attendance_event_yesterday)
        end
      end

      context 'viewing day after tomorrow' do
        let(:date) { today.tomorrow.tomorrow }
        it 'returns day after tomorrow event' do
          expect(date.day).to eq(day_after_tomorrow_date.day)
          cav = select_attendance_event_service.run()
          expect(cav).to eq(course_attendance_event_day_after_tomorrow)
        end
      end

      context 'viewed after final event' do
        let(:date) { day_after_tomorrow_date.tomorrow.tomorrow }
        it 'returns day after tomorrow event' do
          cav = select_attendance_event_service.run()
          expect(cav).to eq(course_attendance_event_day_after_tomorrow)
        end
      end

      # For handling two (or more) events on the same day, there is no simple
      # algorithm for when to switch from viewing the first event of
      # the day to the second. It's not worth the effort of trying to implement
      # something fancy that switches to viewing the second event if the first
      # has had attendance taken and the time has passed, so we just always show
      # the first event of the day and they have to select the second from the
      # dropdown. The only current use case for this is Mock Interviews that can
      # happen the same night of Learning Labs.
      context 'with events on same day' do
        let(:date_6pm) { today.change(hour: 18) }
        let(:date_8pm) { today.change(hour: 20) }

        let!(:canvas_assignment_override_6pm) { create(
          :canvas_assignment_override,
          due_at: date_6pm.iso8601,
        ) }
        let!(:course_attendance_event_6pm) { create(
          :course_attendance_event,
          course: course,
          canvas_assignment_id: canvas_assignment_override_6pm['assignment_id'],
        ) }

        let!(:canvas_assignment_override_8pm) { create(
          :canvas_assignment_override,
          due_at: date_8pm.iso8601,
        ) }
        let!(:course_attendance_event_8pm){ create(
          :course_attendance_event,
          course: course,
          canvas_assignment_id: canvas_assignment_override_8pm['assignment_id'],
        ) }
        let!(:assignment_overrides) { [
          # I confirmed that the 8pm date is first when iterating over this as though Canvas returned
          # them in this order in the JSON API response.
          canvas_assignment_override_yesterday, canvas_assignment_override_day_after_tomorrow,
          canvas_assignment_override_8pm, canvas_assignment_override_6pm
        ] }

        context 'viewed before both events' do
          let(:date) { today.beginning_of_day }
          it 'returns earlier event' do
            cav = select_attendance_event_service.run()
            expect(cav).to eq(course_attendance_event_6pm)
          end
        end

        context 'viewed between events' do
          let(:date) { today.change(hour: 19) }
          it 'returns earlier event' do
            cav = select_attendance_event_service.run()
            expect(cav).to eq(course_attendance_event_6pm)
          end
        end

        context 'viewed after both events' do
          let(:date) { today.end_of_day }
          it 'returns earlier event' do
            cav = select_attendance_event_service.run()
            expect(cav).to eq(course_attendance_event_6pm)
          end
        end
      end # 'multiple attendance events on same day'

    end # 'multiple attendance events'

  end
end
