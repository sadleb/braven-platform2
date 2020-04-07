require 'salesforce_api'

# A helper library to perform the logic that takes folks who are confirmed as part of the
# program in Salesforce and creating their Canvas accounts.
class SyncToLMS

  def self.execute(course_id=nil)
    # TODO: implement this for real. The code below just shows an example of how to hit the SF
    # API, parse the response, and create the users in Canvas using the Canvas API.
    sf = SalesforceAPI.new
    data = sf.get_participant_data()
    json = JSON.parse(data.body)

    # TODO: the logic for who get's sync'd is anyone with a Participant.Status == 'Enrolled'
    # In staging there are duplicate participant objects and folks with Participant = Enrolled, but Candidate == Opted Out.
    # In production, that shouldn't happen. Enrolled will switch to something else like Dropped and there shouldn't be duplicates there.
    # Also, we're going to introduce some cohort mapping logic where if it's not set, they go into a canvas section based on the LL day/time.
    # See: https://bebraven.slack.com/archives/CLNA91PD3/p1586272915014600

    # TODO: this is a hack to just grab the first one while trying to get this working
    participant = json[0]

    contact_info = participant['Contact__r']
    candidate_info = participant['Candidate__r']
    cohort_info = participant['Cohort__r']
    program_info = participant['Program__r']
    status = participant['Status__c']  
    record_type = participant['RecordType']
    candidate_status = candidate_info['Status__c']

    email = contact_info['Email']
    username = email # TODO: if they are nlu, their username isn't their email. it's "#{user_student_id}@nlu.edu"
    first_name = contact_info['FirstName']
    last_name = contact_info['LastName']
    role = record_type['Name']
    fellow_course_id = program_info['Target_Course_ID_in_LMS__c']
    lc_course_id = program_info['LMS_Coach_Course_Id__c']
    timezone = program_info['Default_Timezone__c']
    docusign_template_id = program_info['Docusign_Template_ID__c']

    response = CanvasProdClient.create_user(first_name, last_name, username, email, timezone, docusign_template_id)
    new_canvas_user = JSON.parse(response.body)

    # this will be set if we actually created a new user
    # reasons why it might fail would include existing user
    # already having the email address

    # Not necessarily an error but for now i'll just make it throw
    raise "Couldn't create user #{username} <#{email}> in canvas #{response.body}" if new_canvas_user['id'].nil?
  end

end
