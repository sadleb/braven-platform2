require 'rails_helper'
require 'lrs_xapi_mock'

RSpec.describe LrsXapiMock do

  describe '.handle_request!' do
    let(:request) { ActionDispatch::TestRequest.create }
    let(:user) { create(:fellow_user) }
    let(:url) { "#{Rails.application.secrets.lrs_url}/#{endpoint}" }
    let(:authorization) { "#{LtiConstants::AUTH_HEADER_PREFIX} #{state}" }
    let(:response) { LrsXapiMock.handle_request!(request, endpoint, user) }
    let(:state) { LtiLaunchController.generate_state }
    let(:canvas_assignment_id) { 10 }  # arbitrary id
    let!(:lti_launch) { create(:lti_launch_assignment, state: state, canvas_assignment_id: canvas_assignment_id) }
    let!(:course_rise360_module_version) { create(:course_rise360_module_version, canvas_assignment_id: canvas_assignment_id) }
    let(:response_404) { { body: "Not Found", code: 404 } }
    let(:response_204) { { body: nil, code: 204 } }

    before(:each) do
      allow(request).to receive(:query_parameters).and_return(query_parameters.with_indifferent_access)
      allow(request).to receive(:raw_post).and_return(post_body) if method == 'PUT' || method == 'POST'
      allow(request).to receive(:method).and_return(method)
      allow(request).to receive(:authorization).and_return(authorization)
      allow(GradeModuleForUserJob).to receive(:perform_later).and_return(nil)
      response # This is what makes the request for each test and sets this to the response
    end

    context 'unknown endpoint' do
      let(:endpoint) { 'test_endpoint' }

      context 'GET with no parameters' do
        let(:query_parameters) {{ }}
        let(:method) { 'GET' }

        it 'returns nil' do
          expect(response).to eq(nil)
        end
      end

      context 'PUT with no parameters' do
        let(:query_parameters) {{ }}
        let(:post_body) {{ }.to_json}
        let(:method) { 'PUT' }

        it 'returns 404' do
          expect(response).to eq(response_404)
        end
      end

      context 'POST with no parameters' do
        let(:query_parameters) {{ }}
        let(:post_body) {{ }.to_json}
        let(:method) { 'POST' }

        it 'returns nil' do
          expect(response).to eq(nil)
        end
      end

      context 'DELETE with no parameters' do
        let(:query_parameters) {{ }}
        let(:method) { 'DELETE' }

        it 'returns nil' do
          expect(response).to eq(nil)
        end
      end

    end # context 'any endpoint'

    context 'xAPI statements endpoint' do
      let(:endpoint) { LrsXapiMock::XAPI_STATEMENTS_API_ENDPOINT }

      context 'GET with minimal parameters' do
        let(:query_parameters) {{ 'statementId': 'test' }}
        let(:method) { 'GET' }

        it 'returns nil' do
          expect(response).to eq(nil)
        end
      end

      context 'PUT with minimal parameters' do
        let(:query_parameters) {{ 'statementId': 'test' }}
        let(:post_body) {{ 'testParam': 'test' }.to_json}
        let(:method) { 'PUT' }

        it 'does not save an interaction record' do
          expect(Rise360ModuleInteraction.count).to eq(0)
        end

        it 'returns 204' do
          expect(response).to eq(response_204)
        end
      end

      context 'PUT with progressed verb' do
        let(:query_parameters) {{ 'statementId': 'test' }}
        let(:post_body) {{
          'actor': 'TEST_REPLACED',
          'verb': { 'id': Rise360ModuleInteraction::PROGRESSED },
          'object': { 'id': 'http://example_activity_id' },
          'result': { 'extensions': {
            'http://w3id.org/xapi/cmi5/result/extensions/progress': 30,
          } },
        }.to_json}
        let(:method) { 'PUT' }

        it 'saves an interaction record' do
          expect(Rise360ModuleInteraction.count).to eq(1)
          expect(Rise360ModuleInteraction.last.verb).to eq(Rise360ModuleInteraction::PROGRESSED)
          expect(Rise360ModuleInteraction.last.progress).to eq(30)
          expect(Rise360ModuleInteraction.last.user).to eq(user)
          expect(Rise360ModuleInteraction.last.activity_id).to eq('http://example_activity_id')
        end

        # We only do this when they finish or nighlty b/c it's computationally and memory intensive.
        it 'does not kick off module grading job' do
          expect(GradeModuleForUserJob).not_to have_received(:perform_later)
        end

        it 'returns 204' do
          expect(response).to eq(response_204)
        end
      end

      context 'PUT with progressed 100 verb' do
        let(:query_parameters) {{ 'statementId': 'test' }}
        let(:post_body) {{
          'actor': 'TEST_REPLACED',
          'verb': { 'id': Rise360ModuleInteraction::PROGRESSED },
          'object': { 'id': 'http://example_activity_id' },
          'result': { 'extensions': {
            'http://w3id.org/xapi/cmi5/result/extensions/progress': 100,
          } },
        }.to_json}
        let(:method) { 'PUT' }

        it 'saves an interaction record' do
          expect(Rise360ModuleInteraction.count).to eq(1)
          expect(Rise360ModuleInteraction.last.progress).to eq(100)
        end

        it 'kicks off the module grading job' do
          expect(GradeModuleForUserJob).to have_received(:perform_later)
            .with(user,
                  lti_launch.request_message.canvas_course_id,
                  lti_launch.request_message.custom['assignment_id']
            ).once 
        end

        it 'returns 204' do
          expect(response).to eq(response_204)
        end
      end

      context 'PUT with answered verb' do
        let(:query_parameters) {{ 'statementId': 'test' }}
        let(:post_body) {{
          'actor': 'TEST_REPLACED',
          'verb': { 'id': Rise360ModuleInteraction::ANSWERED },
          'object': { 'id': 'http://example_activity_id' },
          'result': { 'success': true },
        }.to_json}
        let(:method) { 'PUT' }

        it 'saves an interaction record' do
          expect(Rise360ModuleInteraction.count).to eq(1)
          expect(Rise360ModuleInteraction.last.verb).to eq(Rise360ModuleInteraction::ANSWERED)
          expect(Rise360ModuleInteraction.last.success).to eq(true)
          expect(Rise360ModuleInteraction.last.user).to eq(user)
          expect(Rise360ModuleInteraction.last.activity_id).to eq('http://example_activity_id')
        end

        it 'returns 204' do
          expect(response).to eq(response_204)
        end
      end

      context 'PUT with unsupported verb' do
        let(:query_parameters) {{ 'statementId': 'test' }}
        let(:post_body) {{
          'actor': 'TEST_REPLACED',
          'verb': { 'id': 'http://unsupported_verb' },
          'object': { 'id': 'http://example_activity_id' },
          'result': { 'success': true },
        }.to_json}
        let(:method) { 'PUT' }

        it 'does not save an interaction record' do
          expect(Rise360ModuleInteraction.count).to eq(0)
        end

        it 'returns 204' do
          expect(response).to eq(response_204)
        end
      end

    end # context 'xAPI statements endpoint'

    context 'xAPI state endpoint' do
      let(:endpoint) { LrsXapiMock::XAPI_STATE_API_ENDPOINT }

      context 'PUT suspend_data' do
        let(:query_parameters) {{
          'stateId': 'suspend_data',
          'activityId': 'test',
        }}
        let(:method) { 'PUT' }
        let(:post_body) { '{"v":1,"d":[123,34]}' }

        it 'creates a state record if it did not exist' do
          expect(Rise360ModuleState.count).to eq(1)
        end

        it 'updates state record value if it already existed, returns 204' do
          expect(Rise360ModuleState.last.value).to eq(post_body)

          post_body = '{"v":1,"d":[123,34,124]}'
          allow(request).to receive(:raw_post).and_return(post_body)
          response = LrsXapiMock.handle_request!(request, endpoint, user)
          expect(response).to eq(response_204)
          expect(Rise360ModuleState.count).to eq(1)
          expect(Rise360ModuleState.last.value).to eq(post_body)
        end

        it 'returns 204' do
          expect(response).to eq(response_204)
        end

        it 'excepts if validation fails' do
          post_body = 'invalid json'
          allow(request).to receive(:raw_post).and_return(post_body)
          expect {
            LrsXapiMock.handle_request!(request, endpoint, user)
          }.to raise_error
        end
      end

      context 'GET suspend_data' do
        let(:query_parameters) {{
          'stateId': 'suspend_data',
          'activityId': 'test',
        }}
        let(:method) { 'GET' }
        let(:response_body) { '{"v":1,"d":[123,34]}' }

        it 'returns 200 with saved state if it exists' do
          allow(Rise360ModuleState).to receive(:find_by).and_return(Rise360ModuleState.new(value: response_body))
          response = LrsXapiMock.handle_request!(request, endpoint, user)
          expect(response).to eq({code: 200, body: response_body})
        end

        it 'returns 404 if it does not exist' do
          expect(response).to eq(response_404)
        end
      end

      context 'PUT bookmark' do
        let(:query_parameters) {{
          'stateId': 'bookmark',
          'activityId': 'test',
        }}
        let(:method) { 'PUT' }
        let(:post_body) { '#/lessons/xQvXXBKjohmGHnPUlyck9VqMlQ0hgcgy' }

        it 'creates a state record if it did not exist' do
          expect(Rise360ModuleState.count).to eq(1)
        end

        it 'updates state record value if it already existed, returns 204' do
          expect(Rise360ModuleState.last.value).to eq(post_body)

          post_body = '#/lessons/newvalue'
          allow(request).to receive(:raw_post).and_return(post_body)
          response = LrsXapiMock.handle_request!(request, endpoint, user)
          expect(response).to eq(response_204)
          expect(Rise360ModuleState.count).to eq(1)
          expect(Rise360ModuleState.last.value).to eq(post_body)
        end

        it 'returns 204' do
          expect(response).to eq(response_204)
        end

        it 'excepts if validation fails' do
          post_body = 'long string'*200
          allow(request).to receive(:raw_post).and_return(post_body)
          expect {
            LrsXapiMock.handle_request!(request, endpoint, user)
          }.to raise_error
        end
      end

      context 'GET bookmark' do
        let(:query_parameters) {{
          'stateId': 'bookmark',
          'activityId': 'test',
        }}
        let(:method) { 'GET' }
        let(:response_body) { '#/lessons/xQvXXBKjohmGHnPUlyck9VqMlQ0hgcgy' }

        it 'returns 200 with saved state if it exists' do
          allow(Rise360ModuleState).to receive(:find_by).and_return(Rise360ModuleState.new(value: response_body))
          response = LrsXapiMock.handle_request!(request, endpoint, user)
          expect(response).to eq({code: 200, body: response_body})
        end

        it 'returns 404 if it does not exist' do
          expect(response).to eq(response_404)
        end
      end

      context 'PUT cumulative_time' do
        let(:query_parameters) {{
          'stateId': 'cumulative_time',
          'activityId': 'test',
        }}
        let(:method) { 'PUT' }
        let(:post_body) { '3356598' }

        it 'creates a state record if it did not exist' do
          expect(Rise360ModuleState.count).to eq(1)
        end

        it 'updates state record value if it already existed, returns 204' do
          expect(Rise360ModuleState.last.value).to eq(post_body)

          post_body = '2'
          allow(request).to receive(:raw_post).and_return(post_body)
          response = LrsXapiMock.handle_request!(request, endpoint, user)
          expect(response).to eq(response_204)
          expect(Rise360ModuleState.count).to eq(1)
          expect(Rise360ModuleState.last.value).to eq(post_body)
        end

        it 'returns 204' do
          expect(response).to eq(response_204)
        end

        it 'excepts if validation fails' do
          post_body = 'not an int'
          allow(request).to receive(:raw_post).and_return(post_body)
          expect {
            LrsXapiMock.handle_request!(request, endpoint, user)
          }.to raise_error
        end
      end

      context 'GET cumulative_time' do
        let(:query_parameters) {{
          'stateId': 'cumulative_time',
          'activityId': 'test',
        }}
        let(:method) { 'GET' }
        let(:response_body) { '3356598' }

        it 'returns 200 with saved state if it exists' do
          allow(Rise360ModuleState).to receive(:find_by).and_return(Rise360ModuleState.new(value: response_body))
          response = LrsXapiMock.handle_request!(request, endpoint, user)
          expect(response).to eq({code: 200, body: response_body})
        end

        it 'returns 404 if it does not exist' do
          expect(response).to eq(response_404)
        end
      end

    end # context 'xAPI state endpoint'

  end

  describe 'self.fix_broken_suspend_data' do
    subject { LrsXapiMock.send(:fix_broken_suspend_data, data, quiz_breakdown) }

    # data should be a JSON string
    let(:data) { '{}' }
    # the stuff described in the data below has 2 quizzes, 3 questions each
    let(:quiz_breakdown) { [3, 3] }

    context 'with normal data' do
      # If you have to change this data for any reason, you can decode the `d` key by:
      # 1. Copy/pasting the contents of lib/javascript/lzwCompress.js into your
      # browser console.
      # 2. Pasting the contents of the data string below (starting with {"v"...)
      # into your browser console, saving it in a variable `data`.
      # 3. Running: unpacked = JSON.parse(lzwCompress.unpack(data))
      # Then modify `unpacked` as needed, and re-encode it with:
      # 1. data['d'] = lzwCompress.pack(JSON.stringify(unpacked))
      # 2. Get the string to paste back below with: console.log(JSON.stringify(data))
      let(:data) { '{"v":2,"d":[123,34,112,114,111,103,114,101,115,115,34,58,256,108,263,115,111,110,265,267,34,48,266,256,99,266,49,44,257,281,48,48,283,105,278,276,290,280,58,282,34,289,275,277,275,293,49,125,303,283,49,292,281,288,290,299,279,281,125,305,307,294,314,34,50,316,302,283,51,321,303,318,320,300,308,296,310,325,304,34,324,329,294,309,298,333,318,52,321,339,256,311,34,301,326,283,53,344,331,340,337,302,334,54,353,297,346,341,283,55,360,332,356,350,34,56,366,355,312,317,334,57,372,362,368,315,368,334,49,347,301,345,291,380,34,306,382,318,49,391,374,295,361,388,396,369,49,328,396,387,385,313,381,400,283,403,348,313,383,336,404,354,379,400,383,343,356,405,363,390,352,422,417,399,412,375,393,359,427,398,406,431,305,365,434,367,419,393,371,440,373,430,322,390,325,410,450,335,424,49,377,445,418,447,369,50,436,397,441,459,334,50,395,447,423,392,410,411,386,428,462,460,415,469,475,424,50,421,416,435,481,426,484,464,349,466,433,488,446,490,401,353,112,285,287,480,457,429,495,408,479,485,471,319,378,503,413,318,478,474,507,442,283,483,506,489,512,351,510,476,358,524,424,439,493,458,504,370,527,389,468,349,451,389,514,407,34,519,532,456,530,511,437,390,462,470,517,390,536,330,516,465,393,473,555,521,548,49,540,338,501,552,49,543,560,494,522,425,534,409,449,389,559,317,323,452,569,562,492,520,571,562,529,585,531,512,466,497,499,551,589,547,357,393,574,459,505,532,578,463,586,598,580,502,525,342,600,532,487,596,476,602,541,604,513,424,584,515,561,607,34,588,623,606,369,444,546,610,283,545,615,454,550,566,557,305,554,565,556,532,402,612,541,642,625,563,647,562,582,605,590,562,614,628,656,650,622,570,660,401,627,663,597,401,631,636,392,334,564,295,498,294,286,595,659,668,383,652,448,649,327,452,674,611,389,658,541,662,579,626,452,670,537,34,635,603,687,683,369,654,679,572,691,643,624,326,334,705,284,677,500,644,667,633,576,632,481,703,617,694,619,608,575,654,318,708,448,693,448,666,694,697,541,700,648,616,553,452,646,535,688,305,729,673,703,712,723,720,601,509,508,731,706,548,733,758,625,735,655,681,318,737,709,629,376,752,685,538,575,688,383,638,717,562,649,761,401,604,781,414,750,393,713,778,650,757,639,645,760,792,572,49,763,784,443,786,305,739,768,664,466,777,710,466,780,795,431,334,614,97,266,52,283,474,112,274,56,500,676,384,500,274,500,114,114,266,116,114,117,101,283,112,113,266,102,97,108,115,835,417,526,275,824,54,761,799,724,764,719,783,811,625,478,361,751,275,859,730,290,862,283,584,865,695,861,278,334,670,868,635,868,384,864,871,393,468,876,411,876,858,879,747,878,267,383,614,876,867,886,390,588,876,873,879,369,676,53,48,303],"cpv":"f44tQzvG"}' }

      it 'does not change the data' do
        expect(subject).to eq(data)
      end
    end

    context 'with broken data' do
      let(:data) { '{"v":2,"d":[123,34,112,114,111,103,114,101,115,115,34,58,256,108,263,115,111,110,265,267,34,48,266,256,99,266,49,44,257,281,48,48,283,105,278,276,290,280,58,282,34,289,275,277,275,293,49,125,303,283,49,292,281,288,290,299,279,281,125,305,307,294,314,34,50,316,302,283,51,321,303,318,320,300,308,296,310,325,304,34,324,329,294,309,298,333,318,52,321,339,256,311,34,301,326,283,53,344,331,340,337,302,334,54,353,297,346,341,283,55,360,332,356,350,34,56,366,355,312,317,334,57,372,362,368,315,368,334,49,347,301,345,291,380,34,306,382,318,49,391,374,295,361,388,396,369,49,328,396,387,385,313,381,400,283,403,348,313,383,336,404,354,379,400,383,343,356,405,363,390,352,422,417,399,412,375,393,359,427,398,406,431,305,365,434,367,419,393,371,440,373,430,322,390,325,410,450,335,424,49,377,445,418,447,369,50,436,397,441,459,334,50,395,447,423,392,410,411,386,428,462,460,415,469,475,424,50,421,416,435,481,426,484,464,349,466,433,488,446,490,401,353,112,285,287,480,457,429,495,408,479,485,471,319,378,503,413,318,478,474,507,442,283,483,506,489,512,351,510,476,358,524,424,439,493,458,504,370,527,389,468,349,451,389,514,407,34,519,532,456,530,511,437,390,462,470,517,390,536,330,516,465,393,473,555,521,548,49,540,338,501,552,49,543,560,494,522,425,534,409,449,389,559,317,323,452,569,562,492,520,571,562,529,585,531,512,466,497,499,551,589,547,357,393,574,459,505,532,578,463,586,598,580,502,525,342,600,532,487,596,476,602,541,604,513,424,584,515,561,607,34,588,623,606,369,444,546,610,283,545,615,454,550,566,557,305,554,565,556,532,402,612,541,642,625,563,647,562,582,605,590,562,614,628,656,650,622,570,660,401,627,663,597,401,631,636,392,334,564,295,498,294,286,595,659,668,383,652,448,649,327,452,674,611,389,658,541,662,579,626,452,670,537,34,635,603,687,683,369,654,679,572,691,643,624,326,334,705,284,677,500,644,667,633,576,632,481,703,617,694,619,608,575,654,318,708,448,693,448,666,694,697,541,700,648,616,553,452,646,535,688,305,729,673,703,712,723,720,601,509,508,731,706,548,733,758,625,735,655,681,318,737,709,629,376,752,685,538,575,688,383,638,717,562,649,761,401,604,781,414,750,393,713,778,650,757,639,645,760,792,572,49,763,784,443,786,305,739,768,664,466,777,710,466,780,795,431,334,614,97,266,52,283,112,274,56,500,676,51,51,283,274,824,345,369,676,52,50,303],"cpv":"f44tQzvG"}' }
      let(:fixed_data) { '{"v":2,"d":[123,34,112,114,111,103,114,101,115,115,34,58,256,108,263,115,111,110,265,267,34,48,266,256,99,266,49,44,257,281,48,48,283,105,278,276,290,280,58,282,34,289,275,277,275,293,49,125,303,283,49,292,281,288,290,299,279,281,125,305,307,294,314,34,50,316,302,283,51,321,303,318,320,300,308,296,310,325,304,34,324,329,294,309,298,333,318,52,321,339,256,311,34,301,326,283,53,344,331,340,337,302,334,54,353,297,346,341,283,55,360,332,356,350,34,56,366,355,312,317,334,57,372,362,368,315,368,334,49,347,301,345,291,380,34,306,382,318,49,391,374,295,361,388,396,369,49,328,396,387,385,313,381,400,283,403,348,313,383,336,404,354,379,400,383,343,356,405,363,390,352,422,417,399,412,375,393,359,427,398,406,431,305,365,434,367,419,393,371,440,373,430,322,390,325,410,450,335,424,49,377,445,418,447,369,50,436,397,441,459,334,50,395,447,423,392,410,411,386,428,462,460,415,469,475,424,50,421,416,435,481,426,484,464,349,466,433,488,446,490,401,353,112,285,287,480,457,429,495,408,479,485,471,319,378,503,413,318,478,474,507,442,283,483,506,489,512,351,510,476,358,524,424,439,493,458,504,370,527,389,468,349,451,389,514,407,34,519,532,456,530,511,437,390,462,470,517,390,536,330,516,465,393,473,555,521,548,49,540,338,501,552,49,543,560,494,522,425,534,409,449,389,559,317,323,452,569,562,492,520,571,562,529,585,531,512,466,497,499,551,589,547,357,393,574,459,505,532,578,463,586,598,580,502,525,342,600,532,487,596,476,602,541,604,513,424,584,515,561,607,34,588,623,606,369,444,546,610,283,545,615,454,550,566,557,305,554,565,556,532,402,612,541,642,625,563,647,562,582,605,590,562,614,628,656,650,622,570,660,401,627,663,597,401,631,636,392,334,564,295,498,294,286,595,659,668,383,652,448,649,327,452,674,611,389,658,541,662,579,626,452,670,537,34,635,603,687,683,369,654,679,572,691,643,624,326,334,705,284,677,500,644,667,633,576,632,481,703,617,694,619,608,575,654,318,708,448,693,448,666,694,697,541,700,648,616,553,452,646,535,688,305,729,673,703,712,723,720,601,509,508,731,706,548,733,758,625,735,655,681,318,737,709,629,376,752,685,538,575,688,383,638,717,562,649,761,401,604,781,414,750,393,713,778,650,757,639,645,760,792,572,49,763,784,443,786,305,739,768,664,466,777,710,466,780,795,431,334,614,97,266,52,283,112,274,56,500,676,51,51,283,274,824,345,318,474,114,114,266,116,114,117,101,334,676,52,50,303],"cpv":"f44tQzvG"}' }

      it 'fixes the data' do
        expect(subject).to eq(fixed_data)
      end
    end
  end
end
