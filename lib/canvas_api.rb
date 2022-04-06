# frozen_string_literal: true
require 'rest-client'
require 'sis_import_status'

class CanvasAPI
  UserNotOnCanvas = Class.new(StandardError)
  TimeoutError = Class.new(StandardError)

  # TODO: refactor and remove LMSRubric. Let's not use structs for some things
  # and hashes for others: https://app.asana.com/0/1201131148207877/1201902273750974
  LMSRubric = Struct.new(:id, :title)

  attr_reader :canvas_url

  # Custom HTML to prepend to each body.
  # Note: We add a "new HTML" comment here to flag this page as coming from the
  # new content editor. This is referenced in several places in Canvas code.
  # We also wrap the entire contents in a "bz-module" div, so the CSS selectors
  # work as expected.
  PrependHTML = %q(
    <div class="bz-module">
    <!-- BRAVEN_NEW_HTML -->
  )

  # Custom HTML to append to each body.
  AppendHTML = %q(
    </div>
  )

  # Canvas course ID for the Braven Content Library.
  ContentLibraryCourseID = 1
  # For calls that need an account ID, default to account 1.
  # In our case, this currently means the "Braven" account.
  DefaultAccountID = 1

  # Use this to get an instance of the API client with authentication info setup.
  def self.client
    @client_instance ||= new(Rails.application.secrets.canvas_url, Rails.application.secrets.canvas_token)
  end

  def initialize(canvas_url, canvas_token)
    @canvas_url = canvas_url
    @api_url = "#{@canvas_url}/api/v1"
    @global_headers = {
      'Authorization' => "Bearer #{canvas_token}",
    }
  end

  def get(path, params={}, headers={})
    retry_timeout do
      RestClient.get("#{@api_url}#{path}", {params: params}.merge(@global_headers.merge(headers)))
    end
  end

  def post(path, body, headers={})
    retry_timeout do
      RestClient.post("#{@api_url}#{path}", body, @global_headers.merge(headers))
    end
  end

  def put(path, body, headers={})
    retry_timeout do
      RestClient.put("#{@api_url}#{path}", body, @global_headers.merge(headers))
    end
  end

  def delete(path, body={}, headers={})
    retry_timeout do
      # Delete helper method doesn't accept a payload. Have to drop down lower level.
      RestClient::Request.execute(method: :delete,
        url: "#{@api_url}#{path}", payload: body, headers: @global_headers.merge(headers))
    end
  end

  # Wrap a RestClient call with a single retry if the request times out just to avoid
  # having to manually try again if it was a temporary thing. When we ran into this one
  # time it was just a single user in an entire sync that blipped.
  def retry_timeout &block

    # Original call.
    block.call()

  # The exception we actually saw was a ReadTimeout, but let's handle OpenTimeout too. See:
  # https://github.com/rest-client/rest-client/blob/master/lib/restclient/exceptions.rb#L202
  rescue RestClient::Exceptions::Timeout
    Honeycomb.add_field('canvas_api.retry_success', false)
    sleep 0.5
    result = nil
    begin

      # Retry
      result = block.call()

    # Translate this to a nice user friendly error message for Product Support to know what to do
    # if the second try still fails.
    rescue RestClient::Exceptions::Timeout
      raise TimeoutError, "There was a timeout when talking to Canvas. This is usually temporary. " +
                          "Try logging into Canvas to make sure it's generally working and then try again."
    end
    Honeycomb.add_field('canvas_api.retry_success', true)
    result
  end

  def api_user_id
    @api_user_id ||= begin
      response = get('/users/self')
      api_user = JSON.parse(response.body)
      api_user['id']
    end
  end

  def update_course_page(course_id, wiki_page_id, wiki_page_body)
    body = {
      'wiki_page[body]' => PrependHTML + wiki_page_body + AppendHTML,
    }

    put("/courses/#{course_id}/pages/#{wiki_page_id}", body)
  end

  def update_course(canvas_course_id, fields_to_set)
    response = put("/courses/#{canvas_course_id}", fields_to_set)
    JSON.parse(response.body)
  end

  # Submits an assignment for a user that when viewed, launches the specified
  # lti_launch_url as the submission to view.
  #
  # WARNING: This method should only be used in the event that fellows do not ever need to
  # create a submission for an assignment. If this method is used, LTI Advantage API cannot
  # be used to submit the assignment again. Once this method is used to create a submission,
  # future submissions will only be able to be made using this method again, so fellows will
  # never be able to create a submission themselves.
  # Use LtiAdvantage 'to create basic_lti_launch submission types instead'
  def create_lti_submission(canvas_course_id, assignment_id, canvas_user_id, lti_launch_url)
    body = {
       'submission[submission_type]' => 'basic_lti_launch',
       'submission[user_id]' => canvas_user_id,
       'submission[url]' => lti_launch_url
     }

     response = post("/courses/#{canvas_course_id}/assignments/#{assignment_id}/submissions", body)
     JSON.parse(response.body)
  end

  # Get the latest submission for a user's assignment.
  #
  # Note: despite the REST endpoint seeming like it *may* return a list of submissions
  # if there are multiple, it doesn't seem to. If they resubmit, it will just have an
  # "attempts:2" key or something like that. The grader view still shows a list,
  # but I can't seem to get the list through the API. That seems like a good thing though?
  def get_latest_submission(course_id, assignment_id, user_id)
    response = get("/courses/#{course_id}/assignments/#{assignment_id}/submissions/#{user_id}")
    JSON.parse(response.body)
  end

  # Returns all submissions for an assignment in the format:
  # { canvas_user_id => submission }
  def get_assignment_submissions(course_id, assignment_id, filter_out_unopened_assignment_submissions = false)
    response = get("/courses/#{course_id}/assignments/#{assignment_id}/submissions?per_page=100")
    all_submissions = get_all_from_pagination(response)

    all_submissions.filter_map { |s|
      # If an assignment that is a basic_lti_launch submission type has never been opened, the submissions
      # returned may have a nil 'submission_type' which isn't a real one.
      if filter_out_unopened_assignment_submissions and s['submission_type'].nil?
        nil
      else
        [s['user_id'], s]
      end
    }.to_h
  end

  # Get all submission data for a given course, for all assignments/users,
  # including rubric data. This can take a while.
  # https://canvas.instructure.com/doc/api/submissions.html#method.submissions_api.for_students
  def get_submission_data(course_id)
    response = get("/courses/#{course_id}/students/submissions", {
      'per_page': 100,
      'include[]': 'rubric_assessment',
      'student_ids[]': 'all'
    })
    get_all_from_pagination(response)
  end

  def get_unsubmitted_assignment_data(course_id, assignment_ids)
    query_params = "per_page=100&assignment_ids[]=#{assignment_ids.join("&assignment_ids[]=")}&student_ids[]=all&workflow_state=unsubmitted"
    response = get("/courses/#{course_id}/students/submissions?#{query_params}")

    all_submissions = get_all_from_pagination(response)
    submissions_by_assignment = {}
    all_submissions.map { |s|
      # If there isn't already a submission for an assignment id,
      # add a key value pair with the {assignment id: [submissions]}
      # If there are already submissions for an assignment id, add that submission to the list
      if submissions_by_assignment[s['assignment_id']].nil?
        submissions_by_assignment[s['assignment_id']] = [s]
      else
        submissions_by_assignment[s['assignment_id']] << s
      end
    }
    submissions_by_assignment
  end

  # Batch updates grades for multiple users and one assignment using the Canvas Submissions API:
  # https://canvas.instructure.com/doc/api/submissions.html#method.submissions_api.update
  # grades_by_user_id: hash containing canvas_user_id => grade
  def update_grades(course_id, assignment_id, grades_by_user_id)
    body = grades_by_user_id.map { |canvas_user_id, grade|
      [ "grade_data[#{canvas_user_id}][posted_grade]", grade.to_s]
    }.to_h

    response = post(
      "/courses/#{course_id}/assignments/#{assignment_id}/submissions/update_grades",
      body,
    )

    JSON.parse(response.body)
  end

  # Updates a single grade synchronously. Note that update_grades() above does it
  # asynchonously.
  def update_grade(course_id, assignment_id, canvas_user_id, grade)
    body = { 'submission[posted_grade]' => grade.to_s }

    response = put(
      "/courses/#{course_id}/assignments/#{assignment_id}/submissions/#{canvas_user_id}",
      body,
    )

    JSON.parse(response.body)
  end

  def create_user(first_name, last_name, email, sis_id, timezone)
    body = {
        'user[name]' => "#{first_name} #{last_name}",
        'user[short_name]' => first_name,
        'user[sortable_name]' => "#{last_name}, #{first_name}",
        'user[skip_registration]' => true,
        'user[time_zone]' => timezone,
        'pseudonym[unique_id]' => email,
        'pseudonym[send_confirmation]' => false,
        'communication_channel[type]' => 'email',
        'communication_channel[address]' => email,
        'communication_channel[skip_confirmation]' => true,
        'communication_channel[confirmation_url]' => true,
        'pseudonym[sis_user_id]' => sis_id,
        'enable_sis_reactivation' => true
    }
    response = post("/accounts/#{DefaultAccountID}/users", body)
    JSON.parse(response.body)
  end

  # Note: this only searches by email. If we want to search by SIS ID or other things,
  # alter or exclude the 'include[]' param.
  def search_for_user_in_canvas(search_term)
    # Note: Don't use CGI.escape on search_term bc RestClient handles this internally.
    response = get("/accounts/#{DefaultAccountID}/users", {
      'search_term': search_term,
      'include[]': 'email'
    })
    users = JSON.parse(response.body)
    # Only return an object if one and only one user matches the query.
    users.length == 1 ? users[0] : nil
  end

  # https://canvas.instructure.com/doc/api/users.html#method.users.api_show
  def show_user_details(user_id)
    response = get("/users/#{user_id}")
    JSON.parse(response.body)
  end

  # https://canvas.instructure.com/doc/api/logins.html
  def get_logins(user_id)
    response = get("/users/#{user_id}/logins")
    JSON.parse(response.body)
  end

  # Assumes there is only one login per user.
  #
  # This is the login object we set up the Canvas user with. Admins could manually add more,
  # but we don't support that so this could break if that happens.
  def get_login(user_id)
    logins = get_logins(user_id)
    logins.first
  end

  # IMPORTANT: login emails are completely separate from the emails that are
  # used to send Notifications. Those are called communication_channels:
  # https://canvas.instructure.com/doc/api/communication_channels.html
  # The SIS Import sync is responsible for adjusting those.
  def update_login(login_id, new_email, account_id=DefaultAccountID)
    response = put("/accounts/#{account_id}/logins/#{login_id}", {
      'login[unique_id]': new_email,
    })
    JSON.parse(response.body)
  end

  # https://canvas.instructure.com/doc/api/communication_channels.html
  def get_user_communication_channels(user_id)
    response = get("/users/#{user_id}/communication_channels?per_page=100")
    get_all_from_pagination(response)
  end

  def get_user_email_channel_id(user_id, comm_channels = nil)
    channels = comm_channels || get_user_communication_channels(user_id)
    channels.filter { |c| c['type'] == 'email' }.first['id']
  end

  def get_user_email_channel(user_id, email, comm_channels = nil)
    channels = comm_channels || get_user_communication_channels(user_id)
    channels.find { |c| c['type'] == 'email' && c['address'] == email}
  end

  # https://canvas.instructure.com/doc/api/notification_preferences.html#method.notification_preferences.update_preferences_by_category
  # For list of categories, see: https://canvas.instructure.com/doc/api/notification_preferences.html#method.notification_preferences.category_index
  # For list of frequencies, see: https://canvas.instructure.com/doc/api/notification_preferences.html
  def update_notification_preferences_by_category(user_id, communication_channel_id, category, frequency)
    response = put("/users/self/communication_channels/#{communication_channel_id}/notification_preference_categories/#{category}?as_user_id=#{user_id}", {
      'notification_preferences[frequency]': frequency,
    })
    JSON.parse(response.body)
  end

  def disable_user_grading_emails(user_id)
    channel_id = get_user_email_channel_id(user_id)
    update_notification_preferences_by_category(user_id, channel_id, 'grading', 'never')
  end

  # Returns an array of enrollments objects for the course.
  # See: https://canvas.instructure.com/doc/api/enrollments.html
  # Example Usage:
  #   get_course_enrollments(71, [:StudentEnrollment, :TaEnrollment])
  def get_enrollments(course_id, types=[])
    query_params = "per_page=100"
    types.each { |t| query_params += "&type[]=#{t}"}
    response = get("/courses/#{course_id}/enrollments?#{query_params}")
    get_all_from_pagination(response)
  end

  # Gets the enrollments for the specified canvas_user_ids in the specified canvas_course_id
  #
  # Returns: { user_id => [array of enrollments] }
  def get_enrollments_for_course_and_users(canvas_course_id, canvas_user_ids)
    query_params = "per_page=100&include[]=enrollments&user_ids[]=#{canvas_user_ids.join('&user_ids[]=')}"
    response = get("/courses/#{canvas_course_id}/users?#{query_params}")

    get_all_from_pagination(response).to_h { |user|
      [ user['id'], user['enrollments'] ]
    }
  end

  # Enrolls the user in the new course, without modifying any existing data
  def enroll_user_in_course(canvas_user_id, course_id, canvas_role, section_id, limit_privileges_to_course_section=true)
    body = {
      'enrollment[user_id]' => canvas_user_id,
      'enrollment[type]' => canvas_role,
      'enrollment[enrollment_state]' => 'active',
      'enrollment[limit_privileges_to_course_section]' => limit_privileges_to_course_section,
      'enrollment[notify]' => false,
      'enrollment[course_section_id]' => section_id
    }
    post("/courses/#{course_id}/enrollments", body)
  end

  def delete_enrollment(enrollment:)
    cancel_enrollment(
      { 'course_id' => enrollment.course_id, 'id' => enrollment.id }
    )
    nil
  end

  # See: https://canvas.instructure.com/doc/api/enrollments.html#method.enrollments_api.destroy
  # Valid values for task:
  #   conclude, delete,  deactivate
  #
  # Note: when deleting their enrollment and then re-enrolling them, it doesn't appear to lose
  # any data (like magic fields or submissions)
  def cancel_enrollment(enrollment, task='delete')
    response = delete("/courses/#{enrollment['course_id']}/enrollments/#{enrollment['id']}", {'task' => task})
    JSON.parse(response.body)
  end

  # Give the user an "Account Role" from those defined here:
  # https://braven.instructure.com/accounts/1/permissions (click the "Account Roles" tab).
  # Default is full "Account Admin" permissions.
  #
  # This is a little confusing b/c to assign the role you call the "Make an account admin" API:
  #   https://canvas.instructure.com/doc/api/admins.html#method.admins.create
  # which is the same as going to the account settings here:
  #   https://braven.instructure.com/accounts/1/settings
  # clicking on the "Admins" tab, and adding a new "Account Admin".
  #
  # NOTE: We defined our own "Staff Account" role that doesn't have full admin permissions,
  # but does give the permissions we need staff to have.
  def assign_account_role(canvas_user_id, canvas_role_id = CanvasConstants::ACCOUNT_ADMIN_ROLE_ID)
    body = {
      :user_id => canvas_user_id,
      :role_id => canvas_role_id,
      :send_confirmation => false
    }
    response = post("/accounts/#{DefaultAccountID}/admins", body)
    JSON.parse(response.body)
  end

  # Removes the specified "Account Role" for the user.
  # Defaults to removing "Account Admin"
  def unassign_account_role(canvas_user_id, canvas_role_id = CanvasConstants::ACCOUNT_ADMIN_ROLE_ID)
    body = { :role_id => canvas_role_id }
    response = delete("/accounts/#{DefaultAccountID}/admins/#{canvas_user_id}", body)
    JSON.parse(response.body)
  end

  def get_sections(course_id)
    response = get("/courses/#{course_id}/sections?per_page=100")
    get_all_from_pagination(response)
  end

  def create_section(canvas_course_id, section_name, sis_id)
    response = post("/courses/#{canvas_course_id}/sections", {
      'course_section[name]' => section_name,
      'course_section[sis_section_id]' => sis_id
    })
    JSON.parse(response.body)
  end

  def update_section(canvas_section_id, fields_to_set)
    response = put("/sections/#{canvas_section_id}", fields_to_set)
    JSON.parse(response.body)
  end

  def delete_section(section_id)
    response = delete("/sections/#{section_id}")
    JSON.parse(response.body)
  end

  def get_assignment(course_id, assignment_id)
    response = get("/courses/#{course_id}/assignments/#{assignment_id}")
    JSON.parse(response.body)
  end

  # Gets a list of all assignments for a course.
  def get_assignments(course_id)
    response = get("/courses/#{course_id}/assignments?per_page=100")
    get_all_from_pagination(response)
  end

  # Returns a list of assignment overrides for a section in a course filtered
  # by assignment_ids (if specified)
  def get_assignment_overrides_for_section(course_id, course_section_id, assignment_ids=[])
    response = get("/courses/#{course_id}/assignments?include[]=overrides&per_page=100")
    get_all_from_pagination(response)
      .filter { |a| (!assignment_ids.present? || assignment_ids.include?(a['id'])) }
      .select { |a| a['has_overrides'] && a['overrides'].present? }
      .map { |a| a['overrides'].select { |override| override['course_section_id'] == course_section_id }.first }
      .select(&:present?)
  end

  # Returns a list of all assignment overrides in a course.
  def get_assignment_overrides_for_course(course_id)
    response = get("/courses/#{course_id}/assignments?include[]=overrides&per_page=100")
    get_all_from_pagination(response)
      .select { |a| a['has_overrides'] && a['overrides'].present? }
      .map { |a| a['overrides'] }
      .flatten
  end

  # Creates an assignment that will launch an LTI External Tool
  # Note: if you don't specificy a launch_url, you'll have to call
  # back in using update_assignment_lti_launch_url() to set it.
  def create_lti_assignment(course_id, name, launch_url = nil, points_possible = nil, open_in_new_tab = true)
    body = { :assignment =>
      {
        :name => name,
        :published => true,
        :submission_types => [ 'external_tool' ],
        :points_possible => points_possible, # nil just defaults to 0 points
        :external_tool_tag_attributes => {
          :url => launch_url,
          :new_tab => open_in_new_tab,
        }
      }
    }
    response = post("/courses/#{course_id}/assignments", body)
    JSON.parse(response.body)
  end

  def update_assignment_name(course_id, assignment_id, name)
    body = { :assignment => { :name => name } }
    response = put("/courses/#{course_id}/assignments/#{assignment_id}", body)
    JSON.parse(response.body)
  end

  def update_assignment_lti_launch_url(course_id, assignment_id, new_url)
    body = { :assignment => { :external_tool_tag_attributes => { :url => new_url } } }
    response = put("/courses/#{course_id}/assignments/#{assignment_id}", body)
    JSON.parse(response.body)
  end

  def delete_assignment(course_id, assignment_id)
    response = delete("/courses/#{course_id}/assignments/#{assignment_id}")
    JSON.parse(response.body)
  end

  # https://canvas.instructure.com/doc/api/assignments.html#method.assignment_overrides.index
  def get_assignment_overrides(course_id, assignment_id)
    response = get("/courses/#{course_id}/assignments/#{assignment_id}/overrides?per_page=100")
    get_all_from_pagination(response)
  end

  # Associates an AssignmentOverride for each section to each assignment. This causes the
  # Edit Assignment Dates UI to show all the sections so that you can bulk edit the due dates for
  # each section in the UI.
  #
  # See: https://canvas.instructure.com/doc/api/assignments.html#method.assignments_api.index
  def create_assignment_override_placeholders(course_id, assignment_ids, section_ids)
    overrides = []
    assignment_ids.each { |aid|
      section_ids.each { |sid|
        overrides << { :due_at => nil, :assignment_id => aid, :course_section_id => sid }
      }
    }
    body = { :assignment_overrides => overrides }

    response = post("/courses/#{course_id}/assignments/overrides", body)
    JSON.parse(response.body)
  end

  # Create assignment overrides directly from passed-in hashes.
  def create_assignment_overrides(course_id, overrides)
    body = { :assignment_overrides => overrides }

    response = post("/courses/#{course_id}/assignments/overrides", body)
    JSON.parse(response.body)
  end

#  def get_rubric(course_id, rubric_id)
#    response = get("/courses/#{course_id}/rubrics/#{rubric_id}?include[]=assignment_associations")
#    JSON.parse(response)
#  end


  def get_course_rubrics_data(course_id)
    response = get("/courses/#{course_id}/rubrics?per_page=100")
    get_all_from_pagination(response)
  end

  def get_account_rubrics_data(account_id=DefaultAccountID)
    response = get("/accounts/#{account_id}/rubrics?per_page=100")
    get_all_from_pagination(response)
  end

  # Note: unlike get_rubric(), you cannot pass an 'include[]=assignment_associations' parameter to
  # to see which rubrics are already associated with an assignment or not. You can however see that
  # info in the response to get_assigments().
  #
  # filter_out_already_associated: true to only return rubrics that are not already
  #                                associated (attached) to an assignment
  def get_rubrics(course_id, filter_out_already_associated = false)
    response_json = get_course_rubrics_data(course_id)
    result = response_json.map { |r| LMSRubric.new(r['id'], r['title']) }

    if filter_out_already_associated

      # TODO: a better way to do this will be to store rubric_ids on the course_custom_content_versions
      # join  model, but that's more work and we need to handle course clone, and this happens rarely (only when
      # designers are publishing new Projects/Survey), so this is a hack for now.
      # Task to do this properly:
      # https://app.asana.com/0/1174274412967132/1198996949946468
      already_associated_rubrics = CanvasAPI.client.get_assignments(course_id).map do |ca|
        assoc_rubric = ca['rubric_settings']
        CanvasAPI::LMSRubric.new(assoc_rubric['id'], assoc_rubric['title']) if assoc_rubric
      end

      result = result - already_associated_rubrics

    end
    result
  end

  def add_rubric_to_assignment(course_id, assignment_id, rubric_id)
    body = { :rubric_association =>
      {
        :rubric_id => rubric_id,
        :association_id => assignment_id,
        :association_type => 'Assignment',
#        :title => '<insert_assignment_title>',
        :use_for_grading => true,
        :purpose => 'grading'
      }
    }
    response = post("/courses/#{course_id}/rubric_associations", body)
    JSON.parse(response.body)
  end

  # See: https://canvas.instructure.com/doc/api/file.pagination.html
  def get_all_from_pagination(response)
    info = JSON.parse(response.body)
    while response
      link = response.headers[:link]
      break if link.nil?

      # Find the line in the link header that looks like the following and pull the URL out:
      # <https://bebraven.instructure.com/api/v1/courses/:id/assignements>; rel="next"
      match = link.match(/.*<(?<url>.+)>; rel="next"/)
      next_url = (match ? match[:url] : nil)
      if next_url
        # Turn something like this: https://portal.bebraven.org/api/v1/courses/71/enrollments?page=2&per_page=100
        # into this: /courses/71/enrollments?page=2&per_page=100
        # So that we can use the get() convenience method in case we ever add centralized logic / error handling there.
        next_url.sub!(/^.*api\/v1/, '')
        response = get(next_url)
        more_info = JSON.parse(response.body)
        info.concat(more_info)
      else
        response = nil
      end
    end

    info
  end

  # See: https://canvascoach.instructure.com/doc/api/file.file_uploads.html#method.file_uploads.post
  # If successful, URL will be available as the hash value of the 'url' key.
  # If unsuccessful, returns a Response object.
  def upload_file_to_course(file, original_filename, content_type, course_id=ContentLibraryCourseID)
    # Step 1: Telling Canvas about the file upload and getting a token.
    body = {
      name: original_filename,
      size: file.size,
      content_type: content_type,
    }

    response = post("/courses/#{course_id}/files", body)
    return response if response.code != 200

    info = JSON.parse(response.body)

    # Step 2: Upload the file data to the URL given in the previous response.
    response = RestClient.post(info['upload_url'], info['upload_params'].merge(file:file))
    return response if ![200, 301].include? response.code

    # Return preview URL.
    info = JSON.parse(response.body)
    {url: "#{canvas_url}/courses/#{course_id}/files/#{info['id']}/preview"}

  end

  def create_enrollment_term(name, sis_term_id, account_id=DefaultAccountID)
    body = {
      'enrollment_term[name]': name,
      'enrollment_term[sis_term_id]': sis_term_id
    }

    response = post("/accounts/#{account_id}/terms", body)
    JSON.parse(response.body)
  end

  # See: https://canvas.instructure.com/doc/api/courses.html#method.courses.create
  # Returns course Hash on success: https://canvas.instructure.com/doc/api/courses.html#Course
  def create_course(name, sis_id, sis_term_id=nil, time_zone=nil, account_id=DefaultAccountID)

    # See: send_sis_import_zipfile_for_full_batch_update() method for more info about the
    # the undocumented sis_term_id prefix
    body = {
      'course[name]': name,
      'course[sis_course_id]': sis_id,
      'course[term_id]': "sis_term_id:#{sis_term_id}",
      'course[time_zone]': time_zone,
      'offer': true, # published vs unpublished
    }
    response = post("/accounts/#{account_id}/courses", body)
    JSON.parse(response.body)
  end

  # See: https://canvas.instructure.com/doc/api/content_migrations.html#method.content_migrations.create
  # You probably don't want to call this directly; consider using copy_course or another appropriate
  # method instead.
  # Returns a ContentMigration Hash on success: https://canvas.instructure.com/doc/api/content_migrations.html#ContentMigration
  # Progress URL will be in migration['progress_url'].
  def content_migration(object_type, object_id, body)
    # Basic validation.
    raise ArgumentError.new('object_type is invalid') unless ['accounts', 'courses', 'groups', 'users'].include? object_type
    Integer(object_id) rescue raise ArgumentError.new('object_id must be an integer')

    response = post("/#{object_type}/#{object_id}/content_migrations", body)
    JSON.parse(response.body)
  end

  # Gets the progress status of a ContentMigration resulting from calling the above content_migration() method.
  def get_copy_course_status(progress_url)
    # Bypass the helper b/c the progress URL is the full URL returned in content_migration['progress_url']
    response = RestClient.get(progress_url, @global_headers)
    JSON.parse(response.body)
  end

  # Note this uses the content_migration API, not the deprecated course copy API.
  # Example usage:
  #   course_data = create_course('Course Name')
  #   migration_data = copy_course(unlaunched_course.canvas_course_id, course_data['id'])
  def copy_course(source_course_id, destination_course_id)
    content_migration('courses', destination_course_id, {
      'migration_type': 'course_copy_importer',
      'settings[source_course_id]': source_course_id,
    })
  end

  # Query params used for all types of SIS Imports.
  # update_sis_id_if_login_claimed:
  #   In order to handle old users created before this SIS Import infrastructure
  #   was rolled out, we set this to true so that the SIS ID will get updated
  #   if a user with that login is found (aka email)
  #
  # override_sis_stickiness:
  #   This causes the SIS Import data to override any sticky changes made through
  #   made through the UI or API. Without this set, changing their name from what
  #   we originally sent using the API doesn't work
  #
  SIS_IMPORT_DEFAULT_QUERY_PARAMS='import_type=instructure_csv&extension=zip&' +
                                  'update_sis_id_if_login_claimed=true&override_sis_stickiness=true'

  # Sends a zip of SIS Import .csvs to the Canvas SIS Import API as a data_set.
  # See SisImportDataSet for information about data_set_id and diffing_mode_on
  def send_sis_import_zipfile_for_data_set(zipfile, data_set_id, diffing_mode_on)
    query_string = "#{SIS_IMPORT_DEFAULT_QUERY_PARAMS}&" +
                   "diffing_data_set_identifier=#{data_set_id}&" +
                   "diffing_remaster_data_set=#{!diffing_mode_on}"

    response = post(
      "/accounts/#{DefaultAccountID}/sis_imports.json?#{query_string}",
      zipfile
    )
    raw_status = JSON.parse(response.body)
    SisImportStatus.new(raw_status)
  end

  # Sends a zip of SIS Import .csvs to the Canvas SIS Import API in Batch Mode.
  # This mode is used to replace the data for each course in the "term" with this
  # new canonical data_set.
  # See SisImportBatchMode for information.
  #
  # Note: the batch_mode_term_id=sis_term_id:the_term_id format doesn't seem to be
  # documented, but without a sis_term_id prefix the API returns:
  #   {"errors":[{"message":"The specified resource does not exist."}]}
  # I found this format here: https://groups.google.com/g/canvas-lms-users/c/6YDFA9RWS3Y?pli=1
  def send_sis_import_zipfile_for_full_batch_update(zipfile, sis_term_id, change_threshold=nil)
    query_string = "#{SIS_IMPORT_DEFAULT_QUERY_PARAMS}&" +
                   "batch_mode=true&" +
                   "batch_mode_term_id=sis_term_id:#{sis_term_id}"
    query_string << "&change_threshold=#{change_threshold}" if change_threshold

    response = post(
      "/accounts/#{DefaultAccountID}/sis_imports.json?#{query_string}",
      zipfile
    )
    raw_status = JSON.parse(response.body)
    SisImportStatus.new(raw_status)
  end

  def get_sis_imports(created_since = 1.day.ago)
    response = get("/accounts/#{DefaultAccountID}/sis_imports", {
      'created_since': created_since.iso8601(3)
    })
    get_all_from_pagination(response)
  end

  def get_sis_import_status(sis_import_id)
    response = get("/accounts/#{DefaultAccountID}/sis_imports/#{sis_import_id}")
    raw_status = JSON.parse(response.body)
    SisImportStatus.new(raw_status)
  end

end
