FactoryBot.define do

  # Represents a Participant object returned from the Salesforce API

  factory :salesforce_participant, class: Hash do
    skip_create # This isn't stored in the DB.

    transient do
      sequence(:program_id) { |i| "a2Y1700000#{i}WLxqAUX" }
      sequence(:discord_invite_code) { |i| "code#{i}" }
      cohort_schedule_day { 'Monday' }
    end

    # Note: some things that aren't a sequence use it as a hack b/c we can't use Uppercase
    # attribute names
    sequence(:CandidateStatus) { 'Fully Confirmed' }
    sequence(:CohortScheduleDayTime) { |i| "#{cohort_schedule_day}, #{i} pm" }
    sequence(:CohortName) { |i| "TEST Cohort#{i}" }
    sequence(:ProgramId) { program_id }
    sequence(:ContactId) { |i| "a2Y1700000#{i}WLxqEAG" }
    sequence(:Email) { |i| "test#{i}@example.com" }
    sequence(:FirstName) { |i| "TestFirstName#{i}" }
    sequence(:LastName) { |i| "TestLastName#{i}" }
    sequence(:LastModifiedDate) { "2020-04-10T13:27:2{i}.000Z" }
    sequence(:ParticipantStatus) { 'Enrolled' }
    sequence(:StudentId) { |i| "TestSisId#{i}" }
    sequence(:DiscordInviteCode) { discord_invite_code }

    factory :salesforce_participant_fellow do
      sequence(:Role) { :Fellow }
    end

    factory :salesforce_participant_lc do
      sequence(:Role) { :'Leadership Coach' }
    end

    factory :salesforce_participant_ta do
      sequence(:Role) { :'Teaching Assistant' }
    end

    initialize_with { attributes.stringify_keys }
  end

end


# Example (list of two)
#[
#    {
#        "CandidateStatus": "Fully Confirmed",
#        "CohortName": "TEST SJSU - Thursdays",
#        "ContactId": "003170000124dLOAAY",
#        "Email": "brian+testsyncfellowtolmssjsu1@bebraven.org",
#        "FirstName": "Brian",
#        "LastModifiedDate": "2020-04-10T13:27:26.000Z",
#        "LastName": "xTestSyncFellowToLmsSJSU1",
#        "ParticipantStatus": "Enrolled",
#        "Role": "Fellow",
#        "StudentId": null
#    },
#    {
#        "CandidateStatus": "Fully Confirmed",
#        "CohortName": "TEST SJSU - Mondays",
#        "ContactId": "003170000124mfIAAQ",
#        "Email": "brian+testsynclctolmssjsu1@bebraven.org",
#        "FirstName": "Brian",
#        "LastModifiedDate": "2020-04-10T20:53:25.000Z",
#        "LastName": "xTestSyncLCToLmsSJSU1",
#        "ParticipantStatus": "Dropped",
#        "Role": "Leadership Coach",
#        "StudentId": null
#    }
#]
