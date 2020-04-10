require 'rails_helper'
require 'salesforce_api'

RSpec.describe SalesforceAPI do

# TODO: implement these. Use canvas_api_spec.rb for inspiration

  describe 'authentication' do
    xit 'correctly sets authorization header' do
      # Make a request to this API and make sure the 'Authorization: Bearer <token>' is in the header
    end
    
    xit 'gets the access token' do
      # stub out the request to get an access token and make sure it happens.
    end
  end

  describe 'sync_to_lms' do
    xit 'gets program info' do
      # Example response:
#       {"StudentId"=>nil, "Role"=>"Fellow", "ParticipantStatus"=>"Enrolled", "LastName"=>"xTestSyncFellowToLmsSJSU1", "LastModifiedDate"=>"2020-04-10T12:55:43.000Z", "FirstName"=>"Brian", "Email"=>"brian+testsyncfellowtolmssjsu1@bebraven.org", "ContactId"=>"003170000124dLOAAY", "CohortName"=>"Test SJSU - Wednesdays", "CandidateStatus"=>"Fully Confirmed"}
    end

    xit 'gets users to sync' do
      # check that it hits the right end point with the right parameters (e.g. only for a particular program and/or only the modified users).
    end
  end
end
