require 'rails_helper'
require 'sync_to_lms'

RSpec.describe SyncToLMS do

# TODO: implement these. 

  describe 'fetch from Salesforce' do

    xit 'fetches Participants only for the course being synced ' do
    end

    xit 'fetches only modified Participant objects' do
    end

    xit 'parses Participant objects for Fellow' do
      # Make sure the fields needed for the Canvas create user call are properly parsed from the returend Participant Data object.
    end

    xit 'parses Participant objects for LC' do
      # Make sure the fields needed for the Canvas create user call are properly parsed from the returend Participant Data object.
    end

    xit 'processes Enrolled participants with a Cohort set' do
    end
   
    xit 'processes Enrolled participants with no Cohort set' do
      # TODO: the logic will be to lookup their LL day/time and map them to generic canvas sections based on that.
      # See: https://bebraven.slack.com/archives/CLNA91PD3/p1586272915014600
    end

    xit 'handles missing Accelerator course id for Fellow' do
    end

    xit 'handles missing LC Playbook course id for Fellow' do
      # TODO: shoiuld just skip it, we don't need it
    end

    xit 'handles missing Accelerator course id for LC' do
    end

    xit 'handles missing LC Playbook course id for LC' do
    end

    xit 'handles missing Student ID' do
    end

    xit 'handles missing timezone ' do
    end

    xit 'handles missing DocuSign template' do
    end

    xit 'handles missing Pre-Accelerator survey Qualtrics id' do
    end

    xit 'handles missing Post-Accelerator survey Qualtrics id' do
    end

  end

  describe 'push to Canvas' do

    xit 'creates new users' do
    end

    xit 'updates existing users' do
    end

    xit 'creates users in correct course' do
    end

    xit 'creates users in correct section' do
    end

    xit 'moves existing users between sections' do
    end

    xit 'puts users in placeholder sections based on Learning Lab meeting day/times if cohort not set' do
    end

    xit 'creates users with the correct role (aka Student vs TA)' do
    end

    xit 'puts leadership coaches in both the Accelerator and LC Playbook course' do
    end

    xit 'sets NLU usernames correctly' do
      # For NLU, their username isn't their email. It's "#{user_student_id}@nlu.edu" 
    end
  end

end
