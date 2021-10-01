FactoryBot.define do

  # Represents a Participant object returned from the Salesforce API

  factory :salesforce_participant, class: Hash do
    skip_create # This isn't stored in the DB.

    transient do
      sequence(:program_id) { |i| "a2Y1700000#{i}WLxqAUX" }
      sequence(:discord_invite_code) { |i| "code#{i}" }
      sequence(:discord_user_id) { |i| "#{i}" }
      cohort_schedule_day { 'Monday' }
    end

    # Note: some things that aren't a sequence use it as a hack b/c we can't use Uppercase
    # attribute names
    sequence(:Id) { |i| "a2Xz%011dEAA" % i }
    sequence(:CandidateStatus) { 'Fully Confirmed' }
    sequence(:CandidateId) { |i| "a2Ua%011dEAC" % i }
    sequence(:CohortScheduleDayTime) { |i| "#{cohort_schedule_day}, #{i} pm" }
    sequence(:CohortScheduleId) { |i| "a33a%011dAAS" % i }
    sequence(:CohortName) { |i| "TEST Cohort#{i}" }
    sequence(:CohortId) { |i| "a2UVa%011dEAA" % i }
    sequence(:ProgramId) { program_id }
    sequence(:ContactId) { |i| "003z%011dAAQ" % i }
    sequence(:Email) { |i| "test#{i}@example.com" }
    sequence(:FirstName) { |i| "TestFirstName#{i}" }
    sequence(:LastName) { |i| "TestLastName#{i}" }
    sequence(:LastModifiedDate) { "2020-04-10T13:27:2{i}.000Z" }
    sequence(:ParticipantStatus) { 'Enrolled' }
    sequence(:StudentId) { |i| "TestSisId#{i}" }
    sequence(:DiscordInviteCode) { discord_invite_code }
    sequence(:DiscordUserId) { discord_user_id }
    sequence(:ZoomPrefix) { |i| "ZoomPrefix#{1}" }
    sequence(:ZoomMeetingId1) { |i| "%010d" % i}
    sequence(:ZoomMeetingLink1) { nil }
    sequence(:ZoomMeetingId2) { |i| "%010d" % (i + 10000)}
    sequence(:ZoomMeetingLink2) { nil }

    factory :salesforce_participant_fellow do
      sequence(:Role) { :Fellow }
    end

    factory :salesforce_participant_lc do
      sequence(:Role) { :'Leadership Coach' }
      sequence(:VolunteerRole) { 'Leadership Coach' }
    end

    factory :salesforce_participant_ta do
      sequence(:Role) { :'Teaching Assistant' }
    end

    factory :salesforce_participant_cp do
      sequence(:Role) { :'Leadership Coach' }
      sequence(:VolunteerRole) { 'Coach Partner' }
    end

    factory :salesforce_participant_mi do
      sequence(:Role) { :'Mock Interviewer' }
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
