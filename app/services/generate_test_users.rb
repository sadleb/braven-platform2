# frozen_string_literal: true

class GenerateTestUsers
  include Rails.application.routes.url_helpers

  class GenerateTestUsersError < StandardError; end

  def initialize(params)
    @params = params
    @user_contact_ids = []
    @failed_users = []
    @success_users = []
    @programs_to_sync = []
    @sync_error = ""
  end

  def run
    Honeycomb.start_span(name: 'generate_test_users.run') do
      Honeycomb.add_field('generate_test_users.users.count', @params['email'].count)
      new_test_users = generate_test_users()

      unless @failed_users.empty?
        Rails.logger.error(@failed_users.inspect)
        msg = "Some test users failed to generate. The following users failed => #{@failed_users.inspect}"
        Honeycomb.add_alert('generate_test_users.failed_users', msg)
        raise GenerateTestUsersError, msg
      end

      raise @sync_error if @sync_error.present?
    end
  end

  def generate_test_users()
    Rails.logger.info('Started generating test users')

    num_of_users = @params['email'].count
    for index in 0...num_of_users
      begin
        email, last_name = get_email_and_last_name(index)
        role = @params['role'][index]

        # Create Contact
        contact_fields_to_set = {
          'FirstName' => @params['first_name'][index],
          'LastName' => last_name,
          'AccountId' => Rails.application.secrets.salesforce_test_account
        }
        new_contact = SalesforceAPI.client.create_or_update_contact(email, contact_fields_to_set)

        # Create Candidate
        additional_fields = get_candidate_role_fields(role.to_sym)
        candidate_fields_to_set = {
          'RecordTypeId' => get_candidate_record_type_id(role.to_sym),
          'Contact__c' => new_contact['id'],
          'Program__c' => @params['program_id'][index],
          'Account__c' => Rails.application.secrets.salesforce_test_account,
          'Status__c' => 'Fully Confirmed',
          'Registered__c' => true
        }.merge(additional_fields)
        new_candidate = SalesforceAPI.client.create_candidate(candidate_fields_to_set)

        # Create Participant
        participant_fields_to_set = {
          'RecordTypeId' => get_participant_record_type_id(role.to_sym),
          'Contact__c' => new_contact['id'],
          'Candidate__c' => new_candidate['id'],
          'Program__c' => @params['program_id'][index],
          'Account__c' => Rails.application.secrets.salesforce_test_account,
          'Status__c' => 'Enrolled',
          'Cohort_Schedule__c' => @params['cohort_schedule'][index],
          'Cohort__c' => @params['cohort_section'][index]
        }
        new_participant = SalesforceAPI.client.create_participant(participant_fields_to_set)
        # Update the candidate to link to the newly created participant
        updated_candidate = SalesforceAPI.client.update_candidate(new_candidate['id'], {'Participant__c' => new_participant['id']})

        # Create TA assignment
        unless @params['ta'][index] == ""
          ta_assignment_fields_to_set = {
            'Fellow_Participant__c' => new_participant['id'],
            'TA_Participant__c' => @params['ta'][index],
            'Program__c' => @params['program_id'][index],
            'Name' => 'Name Will Autogenerate'
          }
          SalesforceAPI.client.create_ta_assignment(ta_assignment_fields_to_set)
        end

        @programs_to_sync << @params['program_id'][index] unless @programs_to_sync.include?(@params['program_id'][index])
        @user_contact_ids << {'email' => email, 'contact_id' => new_contact['id']}
      rescue => e
        Sentry.capture_exception(e)
        error_response = JSON.parse(e.response)
        error_messages = error_response.map {|err| "#{err['errorCode']} : #{err['message']}"}
        failed_user = {
          'email' => email,
          'first_name' => @params['first_name'][index],
          'last_name' => last_name,
          'error_detail' => "#{e.class}: #{e.message}",
          'error_message' => "#{error_messages}"
        }
        @failed_users << failed_user
      end
    end

    unless @user_contact_ids.empty?
      # Add a delay to ensure participants are finished being created in Salesforce before we try to sync them
      sleep 1.minute
      sync_programs
    end
  end

  def failed_users
    return @failed_users
  end

  def success_users
    return @success_users
  end

  def sync_error_message
    return @sync_error.message if @sync_error.present?
  end

private
  def sync_programs
    @programs_to_sync.each do |program_id|
      SyncSalesforceProgramJob.new.perform(program_id)
    rescue SyncSalesforceProgram::SyncParticipantsError => e
      Sentry.capture_exception(e)
      @sync_error = e
    end

    # update @success_users with their signuptoken
    @user_contact_ids.each do |u|
      # Using SalesforceAPI to get the signup token instead of HerokuConnect since the contact was
      # just created the value may not be availabe yet from HeorkuConnect since it has a slight delay
      signup_token = SalesforceAPI.client.get_contact_signup_token(u['contact_id'])
      user_with_signup_info =  {
      'email' => u['email'],
      'signup_token' => signup_token,
      'signup_url' => new_user_registration_url(signup_token: signup_token, protocol: 'https')
      }
      @success_users << user_with_signup_info
    end
  end

  # Email should be in format email+xTest[Type][Tag]@bebraven.org
  # Last name should be in format xTest[Type][Tag]
  # EX: 'xTestFellowDiscordSignup'
  def get_email_and_last_name(user_index)
    # abbreviate roles greater than one word to the first letters of each word (ex: Teaching Assistant = TA)
    role = @params['role'][user_index]
    role_name_arr = role.split(" ")
    role = role_name_arr.count > 1 ? (role_name_arr.map{|name| name[0]}.join()) : role

    email_part_one = @params['email'][user_index].split('@')[0]
    last_name = "xTest#{role}#{@params['tag'][user_index]}"
    email_part_two = @params['email'][user_index].split('@')[1]

    email_to_check = "#{email_part_one}+#{last_name}@#{email_part_two}"
    user_number = get_unique_suffix(email_to_check)

    full_email = "#{email_part_one}+#{last_name}#{user_number}@#{email_part_two}"
    last_name = "#{last_name}#{user_number}"

    return [full_email, last_name]
  end

  # Check if this email already has an existing user.
  # If there is already a user with the email, increment one and add it
  # to the email until you find an email without an existing user.
  # Return the number to be added to the email and last_name for the new user
  def get_unique_suffix(original_email)
    email = original_email.downcase
    previous_user_emails = @user_contact_ids.map{|u| u['email'].downcase}

    # The email can be used as is if it doesn't already exists in the database or in the users we
    # previously generated while running this service now, otherwise we need to add an incrementor to the email
    count = nil
    while HerokuConnect::Contact.where(email: email).exists? || previous_user_emails.include?(email)
      count ||= 0
      count = count + 1
      email = original_email.downcase.gsub(/@/, "#{count}@")
    end

    count
  end

  def get_candidate_role_fields(role)
    if role == SalesforceConstants::Role::COACH_PARTNER ||
        role == SalesforceConstants::Role::STAFF ||
        role == SalesforceConstants::Role::FACULTY
      additional_fields = { 'Coach_Partner_Role__c' => role }
    else
      additional_fields = { 'Coach_Partner_Role__c' => 'Test' }
    end

    if role == SalesforceConstants::Role::TEACHING_ASSISTANT ||
        role == SalesforceConstants::Role::STAFF ||
        role == SalesforceConstants::Role::FACULTY
      additional_fields = {
        'Background_Check_Status__c' => 'Passed',
        'Background_Check_Completed__c' => Time.now,
        'eSig_Validated_CPP__c' => true,
        'eSig_Agreement_Media__c' => true
      }.merge(additional_fields)
    end
    additional_fields
  end

  # For Candidate and Participant record type ID:
    # LC and CP have the same record type (both get record type LC --> CP gets different Coach_Partner_Role__c)
    # TA, Staff and Faculty have the same record type (both get record type TA --> Staff & Faculty gets different Coach_Partner_Role__c)
  def get_candidate_record_type_id(role)
    case role
    when SalesforceConstants::Role::FELLOW
      return "0121J000001De1qQAC"
    when SalesforceConstants::Role::LEADERSHIP_COACH,
        SalesforceConstants::Role::COACH_PARTNER
      return "0121J000001De1rQAC"
    when SalesforceConstants::Role::TEACHING_ASSISTANT,
        SalesforceConstants::Role::STAFF,
        SalesforceConstants::Role::FACULTY
      return Rails.application.secrets.salesforce_ta_candidate_record_type_id
    end
  end

  def get_participant_record_type_id(role)
    case role
    when SalesforceConstants::Role::FELLOW
      return "0121J000001De1vQAC"
    when SalesforceConstants::Role::LEADERSHIP_COACH,
        SalesforceConstants::Role::COACH_PARTNER
      return "0121J000001De1wQAC"
    when SalesforceConstants::Role::TEACHING_ASSISTANT,
        SalesforceConstants::Role::STAFF, SalesforceConstants::Role::FACULTY
      return Rails.application.secrets.salesforce_ta_participant_record_type_id
    end
  end
end
