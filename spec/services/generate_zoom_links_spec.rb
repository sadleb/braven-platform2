# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe GenerateZoomLinks do
  let(:zoom_client) { instance_double(ZoomAPI) }
  let(:meeting_id) { '1234567890' }
  let(:file_name) { 'google_sheets.csv' }
  let(:participants_file_path) { fixture_file_upload(Rails.root.join('spec/fixtures/zoom_link_csvs/', file_name), 'application/csv') }
  let(:staff_email) { 'staff.to.send.generated.links.to@bebraven.org' }

  describe '#run' do
    let(:participants) { {} }
    let(:registrants) { build_list :zoom_registrant, participants.count }
    let(:success_response) { double(RestClient::Response) }

    before do
      allow(zoom_client).to receive(:add_registrant).and_return(*registrants)
      allow(ZoomAPI).to receive(:client).and_return(zoom_client)
    end

    subject(:run_generate) do
      GenerateZoomLinks.new(meeting_id: meeting_id, participants_file_path: participants_file_path, email: staff_email, participants: participants).run
    end

    context 'for participants' do
      let(:participants) { build_list(:zoom_participant, 3) }

      it 'calls the Zoom API correctly' do
        expect(zoom_client).to receive(:add_registrant).with(meeting_id, *participants[0].values).once
        expect(zoom_client).to receive(:add_registrant).with(meeting_id, *participants[1].values).once
        expect(zoom_client).to receive(:add_registrant).with(meeting_id, *participants[2].values).once
        run_generate
      end

      it 'returns a CSV with links' do
        csv = CSV.new(run_generate)
        header_row = csv.first
        expect(header_row).to eq(['email', 'first_name', 'last_name', 'join_url'])
        csv.each.with_index(0) do |row, i|
          expected_value = [
            participants[i]['email'],
            participants[i]['first_name'],
            participants[i]['last_name'],
            registrants[i]['join_url']
          ]
          expect(row).to eq(expected_value)
        end
      end

      context 'for Meeting ID with whitespace' do
        let(:meeting_id) { '123 456 7890 ' }
        let(:meeting_id_no_whitespace) { '1234567890' }

        it 'removes whitespace' do
          expect(zoom_client).to receive(:add_registrant).with(meeting_id_no_whitespace, *participants[0].values).once
          expect(zoom_client).to receive(:add_registrant).with(meeting_id_no_whitespace, *participants[1].values).once
          expect(zoom_client).to receive(:add_registrant).with(meeting_id_no_whitespace, *participants[2].values).once
          run_generate
        end
      end
    end

  end # END #run


  describe '#validate_and_run' do
    let(:failed_participants) { [] }
    let(:meeting_settings) { {
      'approval_type'=> 0,
      'registrants_confirmation_email'=> false
    } }
    let(:meeting_info) { {
        'id'=> meeting_id,
        'host_id'=>'test_id',
        'type'=> 8,
        'host_email'=>'testhost@test.org',
        'settings'=> meeting_settings,
        'occurrences'=>[
          {
            'start_time' => "#{Time.now}",
            'duration' => 60,
          }
        ]
      } }
    let(:host_info) { { 'type'=> 2 } }
    let(:base_params) { { meeting_id: meeting_id, email: staff_email, participants: participants_file_path } }
    let(:params) { base_params }

    subject(:validate_and_run) do
      GenerateZoomLinks.new(meeting_id: meeting_id, participants_file_path: participants_file_path, email: staff_email).validate_and_run
    end

    before(:each) do
      allow(GenerateZoomLinksJob).to receive(:perform_later)
      allow(ZoomAPI).to receive(:client).and_return(zoom_client)
      allow(zoom_client).to receive(:get_meeting_info)
        .with(meeting_id)
        .and_return(meeting_info)
      allow(zoom_client).to receive(:get_zoom_user)
        .with(meeting_info['host_id'])
        .and_return(host_info)
    end

    context 'with a Meeting ID that is not an integer' do
      let(:meeting_id) { '123hello' }

      it 'raises an error when the meeting ID is not an integer' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/format is invalid. It should be all numbers/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with a meeting ID of a meeting that is not found' do
      before(:each) do
        allow(zoom_client).to receive(:get_meeting_info)
          .with(meeting_id)
          .and_raise(ZoomAPI::ZoomMeetingDoesNotExistError)
      end

      it 'raises an error when the meeting is not found' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/This meeting was not found or has ended/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with a meeting that has already ended' do
      let(:meeting_info) { {
        'id'=> meeting_id,
        'start_time' => "#{Time.now - (61 * 60)}",
        'duration' => 60,
        'type'=> 8,
        'occurrences'=>[]
      } }
      it 'raises an error if generate zoom links is being called for a meeting that has ended' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/This meeting was not found or has ended/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with Zoom host that doesn\t have a licensed account' do
      let(:host_info) { { 'type'=> 1 } }

      it 'raises an error when the host does not have a licensed Zoom account' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/The meeting host does not have a licensed Zoom acount/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with Zoom meeting settings, registration not set to required' do
      let(:meeting_settings) { {
        'approval_type'=> 2,
        'registrants_confirmation_email'=> false
      } }

      it 'raises an error when the registration is not required' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/Registration must be set to required/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with Zoom meeting settings, email notifications turned on' do
      let(:meeting_settings) { {
        'approval_type'=> 0,
        'registrants_confirmation_email'=> true
      } }

      it 'raises an error when the email notifications are turned on' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/Email notifications in the Zoom meeting settings must be turned off/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'for CSV fields with leading and trailing whitespace' do
      let(:file_name) { 'google_sheets_with_whitespace_in_email.csv' }

      it 'strips the whitespace' do
        expect(GenerateZoomLinksJob).to receive(:perform_later)
          .with(meeting_id, participants_file_path, staff_email, [{'email' =>'test@example.whitespace.com', 'first_name' => 'Brian', 'last_name' => 'xTestZoomWithWhitespace1'}]).once
        validate_and_run
      end
    end

    context 'with too many columns' do
      let(:file_name) { 'too_many_columns.csv' }

      it 'raises an error when there are more than 3 columns in the CSV file' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/You have too many columns in your CSV file/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with a blank CSV header' do
      let(:file_name) { 'blank_header.csv' }

      it 'raises an error when a CSV header is missing' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/You have an empty header in your CSV file./)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with a blank CSV cell (non-header)' do
      let(:file_name) { 'blank_cell_non_header.csv' }

      it 'raises an error when a CSV field is left blank' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/You have an empty cell in your CSV file./)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with a header other than \'email\' in first header' do
      let(:file_name) { 'wrong_first_header.csv' }

      it 'raises an error when the first header doesn\'t match \'email\'' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/Your CSV file should have the headers .* instead of 'email'/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with a header other than \'first_name\' in second header' do
      let(:file_name) { 'wrong_second_header.csv' }

      it 'raises an error when the second header doesn\'t match \'first_name\'' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/Your CSV file should have the headers .* instead of 'first_name'/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with a header other than \'last_name\' in third header' do
      let(:file_name) { 'wrong_third_header.csv' }

      it 'raises an error when the third header doesn\'t match \'last_name\'' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/Your CSV file should have the headers .* instead of 'last_name'/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with the email of the meeting host in the email column' do
      let(:file_name) { 'host_email_included.csv' }

      it 'raises an error when the host of the meetings\'s email is included as a participant to register in the CSV file' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/You are trying to register the host of the meeting/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with an in invalid email in the \'email\' column' do
      let(:file_name) { 'invalid_email.csv' }

      it 'raises an error when an improperly formatted email is found in the \'email\' column' do
        expect { validate_and_run }
          .to raise_error(GenerateZoomLinks::GenerateZoomLinksError)
          .with_message(/is an invalid email address/)
        expect(GenerateZoomLinksJob).not_to have_received(:perform_later)
      end
    end

    context 'with a valid CSV file and Zoom settings properly set up' do
      it 'calls the Generate Zoom Links Job' do
        expect(GenerateZoomLinksJob).to receive(:perform_later)
        validate_and_run
      end
    end

    context 'with MacOS Excel - CSV UTF-8 (Comma Delimited).csv format' do
      let(:file_name) { 'utf8_comma_delimited_macOS.csv' }

      it 'parses the participant registration info' do
        expect(GenerateZoomLinksJob).to receive(:perform_later)
          .with(meeting_id, participants_file_path, staff_email, [{'email' =>'test@example.com', 'first_name' => 'Brian', 'last_name' => 'xTest'}]).once
        validate_and_run
      end
    end

    context 'with MacOS Excel - Comma Separated Values.csv format' do
      let(:file_name) { 'comma_separated_values_macOS.csv' }

      it 'parses the participant registration info' do
        expect(GenerateZoomLinksJob).to receive(:perform_later)
          .with(meeting_id, participants_file_path, staff_email, [{'email' =>'test@example.com', 'first_name' => 'Brian', 'last_name' => 'xTest'}]).once
        validate_and_run
      end
    end

    context 'with Google Sheets downloaded as .csv format' do
      it 'parses the participant registration info' do
        expect(GenerateZoomLinksJob).to receive(:perform_later)
          .with(meeting_id, participants_file_path, staff_email, [{'email' =>'test@example.com', 'first_name' => 'Brian', 'last_name' => 'xTest'}]).once
        validate_and_run
      end
    end

  end # END #validate_and_run
end