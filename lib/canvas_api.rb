require 'rest-client'

class CanvasAPI
  UserNotOnCanvas = Class.new(StandardError)

  LMSUser = Struct.new(:id, :email)
  LMSEnrollment = Struct.new(:id, :course_id, :type, :section_id)
  LMSSection = Struct.new(:id, :name)
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
    @client_instance ||= new(ENV['CANVAS_URL'], ENV['CANVAS_TOKEN'])
  end

  def initialize(canvas_url, canvas_token)
    @canvas_url = canvas_url
    @api_url = "#{@canvas_url}/api/v1"
    @global_headers = {
      'Authorization' => "Bearer #{canvas_token}",
    }
  end

  def get(path, params={}, headers={})
    RestClient.get("#{@api_url}#{path}", {params: params}.merge(@global_headers.merge(headers)))
  end

  def post(path, body, headers={})
    RestClient.post("#{@api_url}#{path}", body, @global_headers.merge(headers))
  end

  def put(path, body, headers={})
    RestClient.put("#{@api_url}#{path}", body, @global_headers.merge(headers))
  end

  def delete(path, body={}, headers={})
    # Delete helper method doesn't accept a payload. Have to drop down lower level.
    RestClient::Request.execute(method: :delete,
      url: "#{@api_url}#{path}", payload: body, headers: @global_headers.merge(headers))
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

  # Submits an assignment for a user that when viewed, launches the specified
  # lti_launch_url as the submission to view.
  def create_lti_submission(canvas_course_id, assignment_id, canvas_user_id, lti_launch_url)
    raise NotImplementedError, 'This is going to lead to headaches. It''ll sort of work ' \
      'in certain situations, but fail with permission errors in others. Use LtiAdvantage ' \
      'to create basic_lti_launch submission types instead'
    #  body = {
    #    'submission[submission_type]' => 'basic_lti_launch',
    #    'submission[user_id]' => canvas_user_id,
    #    'submission[url]' => lti_launch_url
    #  }
    #  post("/courses/#{canvas_course_id}/assignments/#{assignment_id}/submissions", body)
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

  # True if a TA or staff member manually entered a grade rather than our code auto-grading it.
  def latest_submission_manually_graded?(course_id, assignment_id, user_id)
    # I thought about use a bulk API call to get the submissions for these users but I'm worried
    # it'll be buggy and harder to maintain. 1 extra API call per user that has done work and getting
    # their grade updated nightly seems fine
    user_submission = get_latest_submission(course_id, assignment_id, user_id)

    # It's hard to implement this by looking for whether the grader was a TA b/c it could
    # have been an admin or designer or some other role that had permission to edit grades.
    # The easiest way is just to assume that if it wasn't this API user, it was a manual override.
    # If we ever change the API user or accidentally set a manual grade that breaks auto-grading,
    # either write a script or implement an admin tool to fix things up.
    #
    # Note: if the submission has been created using LtiScore.new_pending_manual_submission(),
    # the grader_id will be nil. Don't accidentally treat that as manually graded.
    graded_by_id = user_submission['grader_id']
    graded_by_id.present? && graded_by_id != api_user_id
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

  def create_user(first_name, last_name, username, email, salesforce_id, student_id, timezone)
    body = {
        'user[name]' => "#{first_name} #{last_name}",
        'user[short_name]' => first_name,
        'user[sortable_name]' => "#{last_name}, #{first_name}",
        'user[skip_registration]' => true,
        'user[time_zone]' => timezone,
        'pseudonym[unique_id]' => username,
        'pseudonym[send_confirmation]' => false,
        'communication_channel[type]' => 'email',
        'communication_channel[address]' => email,
        'communication_channel[skip_confirmation]' => true,
        'communication_channel[confirmation_url]' => true,
         # Note: the old code used the Join user.id and not the SF id. But now the user account may not
         # be created yet when we're running Sync To LMS.
        'pseudonym[sis_user_id]' => format_to_sis_id(salesforce_id, student_id),
        'enable_sis_reactivation' => true
    }
    response = post("/accounts/#{DefaultAccountID}/users", body)
    JSON.parse(response.body)
  end

  def find_user_by!(email:)
    user = find_user_in_canvas(email)
    raise UserNotOnCanvas, "Email: #{email}" if user.nil?

    LMSUser.new(user['id'], user['email'])
  end

  def find_user_by(email:, salesforce_contact_id:, student_id:)
    user = find_user_in_canvas(email)
    if user.nil?
      user = find_user_in_canvas(
        format_to_sis_id(salesforce_contact_id, student_id)
      )
    end

    return nil if user.nil?

    LMSUser.new(user['id'], user['email'])
  end

  def find_user_in_canvas(search_term)
    # Note: Don't use CGI.escape on search_term bc RestClient handles this internally.
    response = get("/accounts/#{DefaultAccountID}/users", {
      'search_term': search_term,
      'include[]': 'email'
    })
    users = JSON.parse(response.body)
    # Only return an object if one and only one user matches the query.
    users.length == 1 ? users[0] : nil
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
  # used to send Notifications. If you call this, you almost certainly want to
  # fuss with their communication channels using the methods below.
  def update_login(login_id, new_email, account_id=DefaultAccountID)
    response = put("/accounts/#{account_id}/logins/#{login_id}", {
      'login[unique_id]': new_email,
    })
    JSON.parse(response.body)
  end

  # https://canvas.instructure.com/doc/api/communication_channels.html
  def get_user_communication_channels(user_id)
    response = get("/users/#{user_id}/communication_channels")
    get_all_from_pagination(response)
  end

  def get_user_email_channel_id(user_id)
    channels = get_user_communication_channels(user_id)
    channels.filter { |c| c['type'] == 'email' }.first['id']
  end

  def get_user_email_channel(user_id, email)
    channels = get_user_communication_channels(user_id)
    channels.find { |c| c['type'] == 'email' && c['address'] == email}
  end

  def create_user_email_channel(user_id, email, skip_confirmation = true)
    response = post("/users/#{user_id}/communication_channels", {
      'communication_channel[address]': email,
      'communication_channel[type]': 'email',
      'skip_confirmation': skip_confirmation
    })
    JSON.parse(response.body)
  end

  def delete_user_email_channel(user_id, email)
    response = delete("/users/#{user_id}/communication_channels/email/#{email}")
    JSON.parse(response.body)
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

  # Same as get_enrollments() but just for a single user
  def get_user_enrollments(user_id, course_id=nil, types=[])
    query_params = "per_page=100"
    types.each { |t| query_params += "&type[]=#{t}"}
    response = get("/users/#{user_id}/enrollments")
    # TODO: if course_id is sent, filter the response to only include those for that course
    enrollments = get_all_from_pagination(response)
    (enrollments.blank? ? nil : enrollments) # No enrollments returns an empty array and nil is nicer to deal with.
  end

  def find_enrollment(user_id:, course_id:)
    enrollment = get_user_enrollments(user_id, course_id)
      &.filter { |e| e['course_id']&.to_i.eql?(course_id&.to_i) }
      &.last
    return enrollment if enrollment.nil?

    LMSEnrollment.new(enrollment['id'], enrollment['course_id'],
                      enrollment['type'].to_sym, enrollment['course_section_id'])
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

  def find_section_by(course_id:, name:)
    sections = get_sections(course_id)
    section = sections.filter { |s| s['name'] == name }&.first
    return nil if section.nil?

    LMSSection.new(section['id'], section['name'])
  end

  def get_sections(course_id)
    response = get("/courses/#{course_id}/sections?per_page=100")
    get_all_from_pagination(response)
  end

  def create_lms_section(course_id:, name:)
    section = create_section(course_id, name)
    # Check what create section returns
    LMSSection.new(section['id'], section['name'])
  end

  def create_section(course_id, section_name)
    response = post("/courses/#{course_id}/sections", {'course_section[name]' => section_name})
    JSON.parse(response.body)
  end

  def get_assignment(course_id, assignment_id)
    response = get("/courses/#{course_id}/assignments/#{assignment_id}")
    JSON.parse(response.body)
  end

  # Gets a list of all assignments for a course.
  def get_assignments(course_id)
    response = get("/courses/#{course_id}/assignments")
    get_all_from_pagination(response)
  end

  # Returns a list of assignment overrides for a section in a course filtered
  # by assignment_ids (if specified)
  def get_assignment_overrides_for_section(course_id, course_section_id, assignment_ids=[])
    response = get("/courses/#{course_id}/assignments?include[]=overrides")
    get_all_from_pagination(response)
      .filter { |a| (!assignment_ids.present? || assignment_ids.include?(a['id'])) }
      .select { |a| a['has_overrides'] && a['overrides'].present? }
      .map { |a| a['overrides'].select { |override| override['course_section_id'] == course_section_id }.first }
      .select(&:present?)
  end

  # Returns a list of all assignment overrides in a course.
  def get_assignment_overrides_for_course(course_id)
    response = get("/courses/#{course_id}/assignments?include[]=overrides")
    get_all_from_pagination(response)
      .select { |a| a['has_overrides'] && a['overrides'].present? }
      .map { |a| a['overrides'] }
      .flatten
  end

  # Creates an assignment that will launch an LTI External Tool
  # Note: if you don't specificy a launch_url, you'll have to call
  # back in using update_assignment_lti_launch_url() to set it.
  def create_lti_assignment(course_id, name, launch_url = nil)
    body = { :assignment =>
      {
        :name => name,
        :published => true,
        :submission_types => [ 'external_tool' ],
        :external_tool_tag_attributes => {
          :url => launch_url,
          :new_tab => true,
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
    response = get("/courses/#{course_id}/assignments/#{assignment_id}/overrides")
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

  # Note: unlike get_rubric(), you cannot pass an 'include[]=assignment_associations' parameter to
  # to see which rubrics are already associated with an assignment or not. You can however see that
  # info in the response to get_assigments().
  #
  # filter_out_already_associated: true to only return rubrics that are not already
  #                                associated (attached) to an assignment
  def get_rubrics(course_id, filter_out_already_associated = false)
    response = get("/courses/#{course_id}/rubrics")
    response_json = get_all_from_pagination(response)
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

  # See: https://canvas.instructure.com/doc/api/courses.html#method.courses.create
  # Returns course Hash on success: https://canvas.instructure.com/doc/api/courses.html#Course
  # Set publish:false to leave the course in the unpublished state.
  # Set time_zone to IANA time zone string.
  def create_course(name, account_id=DefaultAccountID, publish: true, time_zone: nil)
    body = {
      'course[name]': name,
      'offer': publish,
    }
    body['course[time_zone]'] = time_zone if time_zone

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

  private

  def format_to_sis_id(salesforce_contact_id, student_id)
    "BVSFID#{salesforce_contact_id}-SISID#{student_id}"
  end
end
