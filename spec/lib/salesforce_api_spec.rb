require 'rails_helper'
require 'salesforce_api'

RSpec.describe SalesforceAPI do

  before(:all) do

    ENV['SALESFORCE_HOST'] = 'test.salesforce.com'
    ENV['SALESFORCE_PLATFORM_CONSUMER_KEY'] = 'testkey'
    ENV['SALESFORCE_PLATFORM_CONSUMER_SECRET'] = 'testsecret'
    ENV['SALESFORCE_PLATFORM_USERNAME'] = 'testuser@example.com'
    ENV['SALESFORCE_PLATFORM_PASSWORD'] = 'testpassword'
    ENV['SALESFORCE_PLATFORM_SECURITY_TOKEN'] = 'testtoken'
    SALESFORCE_LOGIN_URL = "https://#{ENV['SALESFORCE_HOST']}"
    SALESFORCE_INSTANCE_URL = 'https://test--staging22.bebraven.org'
    SALESFORCE_DATA_SERVICE_URL = "#{SALESFORCE_INSTANCE_URL}#{SalesforceAPI::DATA_SERVICE_PATH}"
    SALESFORCE_DATA_SERVICE_QUERY_URL = "#{SALESFORCE_DATA_SERVICE_URL}/query"

    WebMock.disable_net_connect!
  end

  before(:each) do
    login_response = { 'instance_url' => SALESFORCE_INSTANCE_URL, 'access_token' => 'test-token' }.to_json
    stub_request(:post, "#{SALESFORCE_LOGIN_URL}/services/oauth2/token").to_return(body: login_response )
  end

  describe '.client' do

    it 'gets an access token' do
      SalesforceAPI.client

      expect(WebMock).to have_requested(:post, "#{SALESFORCE_LOGIN_URL}/services/oauth2/token")
        .with(body: 'grant_type=password&client_id=testkey&client_secret=testsecret&username=testuser%40example.com&password=testpasswordtesttoken').once
    end

    it 'sets the authorization header' do
      stub_request(:any, /#{SALESFORCE_INSTANCE_URL}.*/)
      SalesforceAPI.client.get('/test')

      expect(WebMock).to have_requested(:get, "#{SALESFORCE_INSTANCE_URL}/test")
        .with(headers: {'Authorization'=>'Bearer test-token'}).once
    end

  end

  describe '#get_accelerator_course_id_from_lc_playbook_course_id' do
    it 'calls the correct endpoint' do
      request_url_regex = /#{Regexp.escape(SALESFORCE_DATA_SERVICE_QUERY_URL)}.*/
      program_json = FactoryBot.json(:salesforce_program)
      program = JSON.parse(program_json)

      stub_request(:get, request_url_regex).to_return(body: program_json)

      accelerator_course_id = SalesforceAPI.client.get_accelerator_course_id_from_lc_playbook_course_id(
        program['records'][0]['Canvas_Cloud_LC_Playbook_Course_ID__c'],
      )

      expect(WebMock).to have_requested(:get, request_url_regex).once
      expect(accelerator_course_id).to eq(program['records'][0]['Canvas_Cloud_Accelerator_Course_ID__c'])
    end
  end

  describe '#get_current_and_future_accelerator_programs' do
    let(:request_url) {
      SALESFORCE_DATA_SERVICE_QUERY_URL +
        "?q=SELECT+Id,+Name,+Canvas_Cloud_Accelerator_Course_ID__c,+Canvas_Cloud_LC_Playbook_Course_ID__c,+Discord_Server_ID__c+FROM+Program__c+" \
        "WHERE+RecordType.Name+=+'Course'+" \
          "AND+Canvas_Cloud_Accelerator_Course_ID__c+<>+NULL+" \
          "AND+Status__c+IN+('Current',+'Future')"
    }
    let(:accelerator_course_ids) { [1,2] }
    # must match hardcoded offset in salesforce_current_and_future_programs factory
    let(:lc_playbook_course_ids) { [accelerator_course_ids[0]+1000, accelerator_course_ids[1]+1000] }
    let(:programs_json) { FactoryBot.json(:salesforce_current_and_future_programs, canvas_course_ids: accelerator_course_ids) }

    before(:each) do
      stub_request(:get, request_url).to_return(body: programs_json )
    end

    it 'calls the correct endpoint' do
      response = SalesforceAPI.client.get_current_and_future_accelerator_programs()
      expect(WebMock).to have_requested(:get, request_url).once
      expect(response).to eq(JSON.parse(programs_json)['records'])
    end

    describe '#get_current_and_future_canvas_course_ids' do
      it 'calls the correct endpoint and parses all IDs out' do
        response = SalesforceAPI.client.get_current_and_future_canvas_course_ids()
        expect(WebMock).to have_requested(:get, request_url).once
        expect(response).to eq([accelerator_course_ids[0], lc_playbook_course_ids[0], accelerator_course_ids[1], lc_playbook_course_ids[1]])
      end
    end

    describe '#get_current_and_future_accelerator_canvas_course_ids' do
      it 'calls the correct endpoint and parses only the accelerator IDs out' do
        response = SalesforceAPI.client.get_current_and_future_accelerator_canvas_course_ids()
        expect(WebMock).to have_requested(:get, request_url).once
        expect(response).to eq([accelerator_course_ids[0], accelerator_course_ids[1]])
      end
    end
  end

  describe '#get_program_info(program_id)' do
    let(:program_id) { '003170000125IpSAAU' }

    it 'calls the correct endpoint' do
      request_url_regex = /#{Regexp.escape(SALESFORCE_DATA_SERVICE_QUERY_URL)}.*/
      program_json = FactoryBot.json(:salesforce_program)
      stub_request(:get, request_url_regex).to_return(body: program_json )

      response = SalesforceAPI.client.get_program_info(program_id)

      expect(WebMock).to have_requested(:get, request_url_regex).once
      expect(response).to eq(JSON.parse(program_json)['records'][0])
    end
  end

  describe '#get_fellow_form_assembly_info(canvas_course_id)' do
    let(:canvas_course_id) { 7627462 }

    it 'calls the correct endpoint' do
      request_url_regex = /#{Regexp.escape(SALESFORCE_DATA_SERVICE_QUERY_URL)}.*/
      fellow_form_assembly_info_json = FactoryBot.json(:salesforce_fellow_form_assembly_info)
      stub_request(:get, request_url_regex).to_return(body: fellow_form_assembly_info_json)

      response = SalesforceAPI.client.get_fellow_form_assembly_info(canvas_course_id)

      expect(WebMock).to have_requested(:get, request_url_regex).once
      expect(response).to eq(JSON.parse(fellow_form_assembly_info_json)['records'][0])
    end
  end

  describe '#get_participants()' do
    let(:program_id) { '003170000125IpSAAU' }
    let(:contact_id) { '004170000125IpSAOX' }

    context 'with program_id only' do
      let(:request_url) { "#{SALESFORCE_INSTANCE_URL}/services/apexrest/participants/currentandfuture/?program_id=#{program_id}" }
      let(:participant_json) { "[#{FactoryBot.json(:salesforce_participant_fellow)}]" }
      before(:each) do
        stub_request(:get, request_url).to_return(body: participant_json)
      end

      it 'calls the correct endpoint' do
        response = SalesforceAPI.client.get_participants(program_id)
        expect(WebMock).to have_requested(:get, request_url).once
        expect(response).to eq(JSON.parse(participant_json))
      end

      # This is a wrapper function for get_participants()
      describe '#find_participants_by' do
        context 'with Enrolled participants' do
          let(:participant_json) { "[#{FactoryBot.json(:salesforce_participant_fellow, :ParticipantStatus => 'Enrolled')}]" }
          it 'returns the Enrolled participants as a SFParticipant struct' do
            response = SalesforceAPI.client.find_participants_by(program_id: program_id)
            expect(response.first.is_a?(SalesforceAPI::SFParticipant))
          end
        end

        context 'with Dropped participants' do
          let(:participant_json) { "[#{FactoryBot.json(:salesforce_participant_fellow, :ParticipantStatus => 'Dropped')}]" }
          it 'returns the Enrolled participants as a SFParticipant struct' do
            response = SalesforceAPI.client.find_participants_by(program_id: program_id)
            expect(response.first.is_a?(SalesforceAPI::SFParticipant))
          end
        end

        context 'with Completed participants' do
          let(:participant_json) { "[#{FactoryBot.json(:salesforce_participant_fellow, :ParticipantStatus => 'Completed')}]" }
          it 'returns the Enrolled participants as a SFParticipant struct' do
            response = SalesforceAPI.client.find_participants_by(program_id: program_id)
            expect(response.first.is_a?(SalesforceAPI::SFParticipant))
          end
        end

        context 'with Status: nil participants' do
          let(:participant_json) { "[#{FactoryBot.json(:salesforce_participant_fellow, :ParticipantStatus => nil )}]" }
          it 'does not return the participant' do
            response = SalesforceAPI.client.find_participants_by(program_id: program_id)
            expect(response.count).to be(0)
          end
        end

        context 'with participant roles other than fellow, ta or lc' do
          let(:participant_json) { "[#{FactoryBot.json(:salesforce_participant_fellow)}, #{FactoryBot.json(:salesforce_participant_ta)}, #{FactoryBot.json(:salesforce_participant_lc)}, #{FactoryBot.json(:salesforce_participant_mi)}]" }

          it 'returns all participants with the matching program_id with the roles fellow, ta or lc' do
            response = SalesforceAPI.client.find_participants_by(program_id: program_id)

            expect(response.count).to eq(3)
            response.each do |struct|
              expect(struct.role)
                .to eq(SalesforceAPI::FELLOW)
                .or eq(SalesforceAPI::TEACHING_ASSISTANT)
                .or eq(SalesforceAPI::LEADERSHIP_COACH)
            end
          end
        end
      end
    end

    context 'with program_id and contact_id' do
      it 'calls the correct endpoint' do
        request_url = "#{SALESFORCE_INSTANCE_URL}/services/apexrest/participants/currentandfuture/?program_id=#{program_id}&contact_id=#{contact_id}"
        participant_json = "[#{FactoryBot.json(:salesforce_participant_fellow)}]"
        stub_request(:get, request_url).to_return(body: participant_json)

        response = SalesforceAPI.client.get_participants(program_id, contact_id)

        expect(WebMock).to have_requested(:get, request_url).once
        expect(response).to eq(JSON.parse(participant_json))
      end
    end


    describe "#find_participant" do
      context "when a matching participant with the role of fellow, ta or lc is found" do
        let(:participant_json) { "[#{FactoryBot.json(:salesforce_participant_mi)}, #{FactoryBot.json(:salesforce_participant_fellow)}]" }
        it 'returns the first matching participant' do
          request_url = "#{SALESFORCE_INSTANCE_URL}/services/apexrest/participants/currentandfuture/?program_id=#{program_id}&contact_id=#{contact_id}"
          stub_request(:get, request_url).to_return(body: participant_json)
          response = SalesforceAPI.client.find_participant(contact_id: contact_id, program_id: program_id)

          expect(response.role).to eq(SalesforceAPI::FELLOW)
        end
      end
    end
  end

  describe '#get_participant_id(program_id, contact_id)' do
    let(:program_id) { 'a2Y11000001HY5mEAG' }
    let(:contact_id) { '0031100001iyv8IAAQ' }

    it 'calls the correct endpoint' do
      request_url_regex = /#{Regexp.escape(SALESFORCE_DATA_SERVICE_QUERY_URL)}.*/
      sf_response = '{"totalSize":1,"done":true,"records":[' \
                        '{"attributes":' \
                          '{"type":"Participant__c","url":"/services/data/v49.0/sobjects/Participant__c/a2X11000000lakXEAQ"},' \
                          '"Id":"a2X11000000lakXEAQ"' \
                        '}' \
                     ']}'
      stub_request(:get, request_url_regex).to_return(body: sf_response)

      response = SalesforceAPI.client.get_participant_id(program_id, contact_id)

      expect(WebMock).to have_requested(:get, request_url_regex).once
      expect(response).to eq('a2X11000000lakXEAQ')
    end

    it 'returns nil when not found' do
      request_url_regex = /#{Regexp.escape(SALESFORCE_DATA_SERVICE_QUERY_URL)}.*/
      sf_response = '{"totalSize":0,"done":true,"records":[]}'
      stub_request(:get, request_url_regex).to_return(body: sf_response)

      response = SalesforceAPI.client.get_participant_id(program_id, contact_id)

      expect(WebMock).to have_requested(:get, request_url_regex).once
      expect(response).to eq(nil)
    end
  end

  describe '#update_zoom_links' do
    let(:id) { 'a2X11000050lakXEAQ' }
    let(:link1) { 'https://zoom.link1' }
    let(:link2) { 'https://zoom.link2' }
    let(:request_url) { SALESFORCE_DATA_SERVICE_URL + "\/sobjects\/Participant__c\/#{id}" }

    it 'calls the correct endpoint' do
      stub_request(:patch, request_url)
      response = SalesforceAPI.client.update_zoom_links(id, link1, link2)
      expect(WebMock).to have_requested(:patch, request_url)
        .with(body: '{"Webinar_Access_1__c":"https://zoom.link1","Webinar_Access_2__c":"https://zoom.link2"}').once
    end
  end

  describe '#get_cohort_schedule_section_names(program_id)' do
    let(:program_id) { '003170000125IpSAAU' }
    let(:request_url) {
      "#{SALESFORCE_DATA_SERVICE_QUERY_URL}?q=SELECT+DayTime__c+FROM+CohortSchedule__c+WHERE+Program__r.Id='#{program_id}'"
    }
    let(:cohort_schedule1) { FactoryBot.json(:salesforce_cohort_schedule) }
    let(:cohort_schedule2) { FactoryBot.json(:salesforce_cohort_schedule) }
    let(:done) { 'true' }
    let(:next_records_json) { '' }
    let(:cohort_schedule_json) { '{"totalSize":2, "done":' + done + ', "records":' + "[#{cohort_schedule1}, #{cohort_schedule2}]#{next_records_json}}" }

    it 'calls the correct endpoint' do
      stub_request(:get, request_url).to_return(body: cohort_schedule_json)
      response = SalesforceAPI.client.get_cohort_schedule_section_names(program_id)
      expect(WebMock).to have_requested(:get, request_url).once
    end

    it 'parses the response into an array of Canvas section names' do
      stub_request(:get, request_url).to_return(body: cohort_schedule_json)
      response = SalesforceAPI.client.get_cohort_schedule_section_names(program_id)
      expect(response).to eq([JSON.parse(cohort_schedule1)['DayTime__c'], JSON.parse(cohort_schedule2)['DayTime__c'] ])
    end

    it 'handles an empty response' do
      stub_request(:get, request_url).to_return(body: '{"totalSize":0, "done":true, "records":[]}')
      response = SalesforceAPI.client.get_cohort_schedule_section_names(program_id)
      expect(response).to eq([])
    end

    context 'with paged response' do
      let(:done) { 'false' }
      let(:next_records_path) { "#{SalesforceAPI::DATA_SERVICE_PATH}/query/01gD0000002HU6KIAW-2000" }
      let(:next_records_json) { ', "nextRecordsUrl":"' + next_records_path + '"' }

      it 'gets full list' do
        cohort_schedule3 = FactoryBot.json(:salesforce_cohort_schedule)
        next_cohort_schedule_json = '{"totalSize":1, "done":true, "records":[' + cohort_schedule3 + ']}'
        stub_request(:get, request_url).to_return(body: cohort_schedule_json)
        stub_request(:get, "#{SALESFORCE_INSTANCE_URL}#{next_records_path}").to_return(body: next_cohort_schedule_json)
        response = SalesforceAPI.client.get_cohort_schedule_section_names(program_id)
        expect(response).to eq([JSON.parse(cohort_schedule1)['DayTime__c'], JSON.parse(cohort_schedule2)['DayTime__c'], JSON.parse(cohort_schedule3)['DayTime__c'] ])
      end
    end

  end

  describe '#get_cohort_names(program_id)' do
    let(:program_id) { '003170000125IpSAAU' }
    let(:request_url) {
      "#{SALESFORCE_DATA_SERVICE_QUERY_URL}?q=SELECT+Name+FROM+Cohort__c+WHERE+Program__r.Id='#{program_id}'"
    }
    let(:cohort1) { FactoryBot.json(:salesforce_cohort) }
    let(:cohort2) { FactoryBot.json(:salesforce_cohort) }
    let(:done) { 'true' }
    let(:next_records_json) { '' }
    let(:cohort_json) { '{"totalSize":2, "done":' + done + ', "records":' + "[#{cohort1}, #{cohort2}]#{next_records_json}}" }

    it 'calls the correct endpoint' do
      stub_request(:get, request_url).to_return(body: cohort_json)
      response = SalesforceAPI.client.get_cohort_names(program_id)
      expect(WebMock).to have_requested(:get, request_url).once
    end

    it 'parses the response into an array of Canvas section names' do
      stub_request(:get, request_url).to_return(body: cohort_json)
      response = SalesforceAPI.client.get_cohort_names(program_id)
      expect(response).to eq([JSON.parse(cohort1)['Name'], JSON.parse(cohort2)['Name'] ])
    end

    it 'handles an empty response' do
      stub_request(:get, request_url).to_return(body: '{"totalSize":0, "done":true, "records":[]}')
      response = SalesforceAPI.client.get_cohort_names(program_id)
      expect(response).to eq([])
    end

    context 'with paged response' do
      let(:done) { 'false' }
      let(:next_records_path) { "#{SalesforceAPI::DATA_SERVICE_PATH}/query/01gD0000002HU6KIAW-2001" }
      let(:next_records_json) { ', "nextRecordsUrl":"' + next_records_path + '"' }

      it 'gets full list' do
        cohort3 = FactoryBot.json(:salesforce_cohort)
        next_cohort_json = '{"totalSize":1, "done":true, "records":[' + cohort3 + ']}'
        stub_request(:get, request_url).to_return(body: cohort_json)
        stub_request(:get, "#{SALESFORCE_INSTANCE_URL}#{next_records_path}").to_return(body: next_cohort_json)
        response = SalesforceAPI.client.get_cohort_names(program_id)
        expect(response).to eq([JSON.parse(cohort1)['Name'], JSON.parse(cohort2)['Name'], JSON.parse(cohort3)['Name'] ])
      end
    end

  end

  describe '#get_contact_info(contact_id)' do
    let(:contact_id) { '003170000125IpSAAU' }

    it 'calls the correct endpoint' do
      contact_json = FactoryBot.json(:salesforce_contact)
      request_url_regex = /#{SALESFORCE_INSTANCE_URL}#{SalesforceAPI::DATA_SERVICE_PATH}\/sobjects\/Contact\/#{contact_json['id']}.*/
      stub_request(:get, request_url_regex).to_return(body: contact_json )

      response = SalesforceAPI.client.get_contact_info(contact_json['id'])

      expect(WebMock).to have_requested(:get, request_url_regex).once
      expect(response).to eq(JSON.parse(contact_json))
    end
  end

  describe '#set_canvas_user_id(contact_id, canvas_user_id)' do
    let(:contact_id) { '003170000125IpSAAU' }

    it 'calls the correct endpoint' do
      contact_json = FactoryBot.json(:salesforce_contact)
      request_url_regex = /#{SALESFORCE_INSTANCE_URL}#{SalesforceAPI::DATA_SERVICE_PATH}\/sobjects\/Contact\/#{contact_json['id']}.*/
      stub_request(:patch, request_url_regex)

      response = SalesforceAPI.client.set_canvas_user_id(contact_json['id'], '1234')

      expect(WebMock).to have_requested(:patch, request_url_regex).once
    end
  end

  describe '#set_canvas_course_ids(program_id, canvas_fellow_course_id, canvas_lc_course_id)' do
    let(:program_id) { '003170000125IpSAAU' }

    it 'calls the correct endpoint' do
      program_json = FactoryBot.json(:salesforce_program)
      request_url_regex = /#{SALESFORCE_INSTANCE_URL}#{SalesforceAPI::DATA_SERVICE_PATH}\/sobjects\/Program__c\/#{program_json['id']}.*/
      stub_request(:patch, request_url_regex)

      response = SalesforceAPI.client.set_canvas_course_ids(program_json['id'], '1234', '5678')

      expect(WebMock).to have_requested(:patch, request_url_regex).once
    end
  end

  describe '.get_contact_signup_token' do
    let(:contact_id) { '003170000125IpSAAU' }
    let(:contact_obj) { { Signup_Token__c: 'test' } }

    it 'calls the correct endpoint' do
      request_url_regex = /#{SALESFORCE_INSTANCE_URL}#{SalesforceAPI::DATA_SERVICE_PATH}\/sobjects\/Contact\/#{contact_id}.*/
      stub_request(:get, request_url_regex).to_return(body: contact_obj.to_json  )

      response = SalesforceAPI.client.get_contact_signup_token(contact_id)

      expect(WebMock).to have_requested(:get, request_url_regex).once
      expect(response).to eq(contact_obj[:Signup_Token__c])
    end
  end

  describe '.update_contact' do
    let(:contact_id) { '003170000125IpSAAU' }
    let(:contact_obj) { { some_field: 'some_value' } }
    let(:request_url_regex) { /#{SALESFORCE_INSTANCE_URL}#{SalesforceAPI::DATA_SERVICE_PATH}\/sobjects\/Contact\/#{contact_id}/ }

    it 'calls the correct endpoint' do
      stub_request(:patch, request_url_regex)

      response = SalesforceAPI.client.update_contact(contact_id, contact_obj)

      expect(WebMock).to have_requested(:patch, request_url_regex)
        .with(body: contact_obj.to_json)
        .once
    end

    context 'when UNABLE_TO_LOCK_ROW response' do
      let(:error_response_json) { '[{"message":"unable to obtain exclusive access to this record or 1 records: 0035cFAKEIDAQBGAA4","errorCode":"UNABLE_TO_LOCK_ROW","fields":[]}]' }

      it 'retries the request once' do
        stub_request(:patch, request_url_regex).to_return(
          {status: 500, body: error_response_json},
          {status: 204}
        )
        sf_client = SalesforceAPI.client
        expect(sf_client).to receive(:sleep).and_return(0.5).once

        response = sf_client.update_contact(contact_id, contact_obj)

        expect(WebMock).to have_requested(:patch, request_url_regex).twice
        expect(response.code).to eq(204)
      end
    end
  end
end
