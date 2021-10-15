# frozen_string_literal: true
require 'execjs'

# Mocks responses to LRS/xAPI requests.
#
# This allows us to support Rise 360 content, without actually having an LRS.
# Rise360 sends and receives payloads to the /activities/state xAPI endpoint that are things like
# like the following, both JSON and just plain content, but for both it expects the Content-Type to
# be 'application/octet-stream' (or perhaps something equivalent, but this is what the browser shows).
#   stateId=cumulative_time:    123456 or NaN
#   stateId=bookmark:           #/lessons/xQvXXBKjohmGHnPUlyck9VqMlQ0hgcgy
#   stateId=suspend_data:       {"v":1,"d":[123,34]]}
class LrsXapiMock

  XAPI_STATE_API_ENDPOINT = 'activities/state'
  XAPI_STATEMENTS_API_ENDPOINT = 'statements'
  OCTET_STREAM_MIME_TYPE = 'application/octet-stream'
  SUSPEND_DATA_STATE_ID = 'suspend_data'
  CUMULATIVE_TIME_STATE_ID = 'cumulative_time'
  BOOKMARK_STATE_ID = 'bookmark'
  # Note: bookmark max length is an arbitrary "small" number so that people can't
  # shove large files in here and use us as a file host. More details on expected
  # bookmark values below.
  BOOKMARK_MAX_LENGTH = 256
  LRS_PATH = '/data/xAPI'

  class LrsXapiMockError < StandardError; end

  # Returns a hash with keys {:code, :body}, OR nil.
  def self.handle_request!(request, endpoint, user)
    Honeycomb.start_span(name: 'lrs_xapi_mock.handle_request!') do |span|
      Honeycomb.add_field('lrs_xapi_mock.path', "/#{endpoint}")
      Honeycomb.add_field('xapi.request.method', request.method)

      return unless request.method == 'GET' || request.method == 'PUT'

      # Get the current LtiLaunch, and exit early if it doesn't have the
      # required context. We don't save interactions for things that aren't
      # assignments (e.g. Course Resources).
      unless request.authorization&.start_with? LtiConstants::AUTH_HEADER_PREFIX
        return {
          code: 403,  # Forbidden
          body: 'Refusing to process xAPI request without assignment.',
        }
      end
      lti_launch = get_lti_launch(request.authorization)
      lti_launch&.add_to_honeycomb_trace()
      unless lti_launch&.course_id && lti_launch&.assignment_id
        return {
          code: 403,  # Forbidden
          body: 'Refusing to process xAPI request without assignment.',
        }
      end

      state_id = request.params['stateId']
      activity_id = request.params['activityId']
      Honeycomb.add_field('xapi.state_id', state_id)
      Honeycomb.add_field('xapi.activity_id', activity_id)

      # Handle PUT for both endpoints.
      if request.method == 'PUT'
        data = request.raw_post

        case endpoint
        when XAPI_STATEMENTS_API_ENDPOINT
          # Save relevant info from statements, for grading purposes.
          save_interaction!(data, lti_launch, user)
          return {
            code: 204,  # No Content
            body: nil,
          }
        when XAPI_STATE_API_ENDPOINT
          # Save the state.
          save_state!(activity_id, state_id, data, lti_launch, user)
          return {
            code: 204,  # No Content
            body: nil,
          }
        else
          return {
            code: 404,  # Not Found
            body: 'Not Found',
          }
        end
      end

      # Handle GET only for the state endpoint.
      if request.method == 'GET' and endpoint == XAPI_STATE_API_ENDPOINT
        # Return the state.
        state = get_state(activity_id, state_id, lti_launch, user)
        if state
          return {
            code: 200,  # OK
            body: state.value,
          }
        else
          return {
            code: 404,  # Not Found
            body: 'Not Found',
          }
        end
      end
    end
  end

private

  private_class_method def self.get_lti_launch(authorization)
    # Get course and assignment IDs from the LtiLaunch specified in the auth header.
    # Header looks like "<prefix> <state>".
    state = authorization.split(LtiConstants::AUTH_HEADER_PREFIX).last.strip
    LtiLaunch.from_state(state)
  end

  private_class_method def self.save_state!(activity_id, state_id, data, lti_launch, user)
    Honeycomb.add_field('xapi.state_data', data)
    # Since this returns data as application/octet-stream, a dangerous mimetype, let's
    # do some extra validation to make it less likely someone can use this as an
    # arbitrary file host for nefarious purposes.
    # The following are known Rise360 state IDs and their expected types.
    # Raise an exception if any of them fail validation.
    case state_id
    when SUSPEND_DATA_STATE_ID
      # E.g.: {v: 1, d: [123, 34, 112, 114, ...]}
      JSON.parse(data)
    when CUMULATIVE_TIME_STATE_ID
      # E.g.: 37561
      Integer(data)
    when BOOKMARK_STATE_ID
      # E.g.: #/lessons/xQvXXBKjohmGHnPUlyck9VqMlQ0hgcgy
      raise LrsXapiMockError.new("bookmark max length exceeded") unless data.length < BOOKMARK_MAX_LENGTH
    else
      raise LrsXapiMockError.new("unknown stateId")
    end

    # There's a weird bug where sometimes your quiz can think it's on the last
    # (results) page, but somehow doesn't have all the fields it's supposed to
    # compute once you reach that page. We don't know how to reproduce this, but
    # it makes it so people can't continue past the quiz, so we need to fix it.
    # If the data wasn't broken, this will just leave it as-is.
    if state_id == SUSPEND_DATA_STATE_ID
      # Get the Rise360ModuleVersion for this assignment ID.
      module_version = CourseRise360ModuleVersion
        .find_by(canvas_assignment_id: lti_launch.assignment_id)
        .rise360_module_version
      Honeycomb.add_field('rise360_module_version.id', module_version.id.to_s)

      data = fix_broken_suspend_data(data, module_version.quiz_breakdown)
    end

    # Continue saving the state.
    attributes = {
      canvas_course_id: lti_launch.course_id,
      canvas_assignment_id: lti_launch.assignment_id,
      activity_id: activity_id,
      user: user,
      state_id: state_id,
    }

    module_state = Rise360ModuleState.find_by(attributes)
    Honeycomb.add_field('xapi.new_state?', module_state.nil?)
    if module_state
      module_state.update!(value: data)
    else
      attributes[:value] = data
      Rise360ModuleState.create!(attributes)
    end
  end

  private_class_method def self.get_state(activity_id, state_id, lti_launch, user)
    state = Rise360ModuleState.find_by(
      canvas_course_id: lti_launch.course_id,
      canvas_assignment_id: lti_launch.assignment_id,
      activity_id: activity_id,
      user: user,
      state_id: state_id,
    )
    Honeycomb.add_field('xapi.state_data', state&.value)
    state
  end

  private_class_method def self.save_interaction!(data, lti_launch, user)
    # Get verb and activity_id from the payload.
    payload = JSON.parse(data)
    verb = payload.dig('verb', 'id')
    activity_id = payload.dig('object', 'id')

    # Exit early if it's not a supported verb.
    return unless (
      verb == Rise360ModuleInteraction::PROGRESSED or
      verb == Rise360ModuleInteraction::ANSWERED
    )

    # Save to the db, raise an exception if any part of this fails.
    # We want this to 500 out if there's anything unexpected.
    case verb
    when Rise360ModuleInteraction::PROGRESSED
      progress = payload.dig('result', 'extensions',
        'http://w3id.org/xapi/cmi5/result/extensions/progress'
      )
      Rise360ModuleInteraction.create_progress_interaction(
        user, lti_launch, activity_id, progress
      )
    when Rise360ModuleInteraction::ANSWERED
      Rise360ModuleInteraction.create!(
        verb: verb,
        user: user,
        canvas_course_id: lti_launch.course_id,
        canvas_assignment_id: lti_launch.assignment_id,
        activity_id: activity_id,
        success: payload.dig('result', 'success')
      )
    end
  end

  # Fix the weird broken suspend_data bug.
  private_class_method def self.fix_broken_suspend_data(data_json, quiz_breakdown)
    Honeycomb.start_span(name: 'xapi.fix_broken_suspend_data') do
      # First, decompress the data. It's compressed using lzwCompress.js, which
      # doesn't seem to have a Ruby equivalent, so unfortunately that means we
      # have to run JavaScript here.
      Honeycomb.add_field('xapi.compiled_js?', defined?(@lzw_compress).nil?)
      @lzw_compress ||= Honeycomb.start_span(name: 'xapi.fix_broken_suspend_data.compile') do
        ExecJS.compile(
          File.open(Rails.root.join('lib/javascript/lzwCompress.js')).read()
        )
      end

      # The Rise format puts the compressed data in the `d` key.
      data = nil
      packed_data = nil
      Honeycomb.start_span(name: 'xapi.fix_broken_suspend_data.parse') do
        data = JSON.parse(data_json)
        packed_data = data['d']
      end

      # At this point we should just have an Array<Integer>. Let's make sure, since
      # we're about to `eval` it on our server. :(
      return data_json unless packed_data.is_a? Array
      return data_json unless packed_data.all? { |x| x.is_a? Integer }

      # Unpack the packed data, which is now hopefully safe to eval. :(
      unpacked_json = nil
      unpacked_data = nil
      Honeycomb.start_span(name: 'xapi.fix_broken_suspend_data.unpack') do
        unpacked_json = @lzw_compress.eval("lzwCompress.unpack(JSON.parse('#{packed_data}'))")
        Honeycomb.add_field_to_trace('xapi.unpacked_json', unpacked_json)
        unpacked_data = JSON.parse(unpacked_json)
      end

      # The resulting object should look something like this:
      # {
      #   progress: {
      #     lessons: {
      #       0: {c: 1, p: 100, i: {...}},  // Not a quiz
      #       1: {c: 1, p: 100, i: {...}},  // Not a quiz
      #       2: {a: 4, c: 1, ps: 80, p: 100, s: 33, ...},  // Quiz!
      #     }
      #   }
      # }
      # Where each lesson represents one section in the module, and is
      # either a quiz or a non-quiz section.
      lessons = unpacked_data.dig('progress', 'lessons')
      return data_json unless lessons

      # IFF the lesson value has an `a` key, it's a mastery quiz.
      # We only care about mastery quizzes, since that's where the bug is.
      # We also only care when `a` is equal to the number of questions in this
      # quiz, plus one; when the user is on the "results" page of the quiz.
      # Finally, we only care when the other values that are supposed to be
      # there, are not there.
      found_bug = false
      quiz_number = -1
      Honeycomb.start_span(name: 'xapi.fix_broken_suspend_data.loop') do
        lessons.each do |key, value|
          next if value['a'].nil?
          # If this is a quiz, increment the quiz_number.
          quiz_number += 1

          quiz_questions = quiz_breakdown[quiz_number] || 0
          next unless value['a'] == quiz_questions + 1
          next if value['c'] && value['rr']

          # Here's the bug!
          found_bug = true
          Honeycomb.add_field('alert.xapi_suspend_data_bug', true)
          Honeycomb.add_field('xapi.suspend_data.lessons', lessons.to_json)
          # Fix it!
          # The bug shows up when you're on the Quiz results screen
          # (`a` = number_of_questions + 1)
          # but somehow Rise didn't correctly compute all the other values
          # it's supposed to put into the object once you hit that screen
          # (`c`, `rr`, and `pq`).
          # `c` should always = 1 once you've finished the quiz (c: completed);
          # when it's nil, the module thinks you haven't completed the quiz and
          # doesn't let you continue to the next section.
          # `rr` should always = true once you've finished the quiz (no idea what
          # it stands for); when it's nil, the module shows a broken screen
          # instead of the nice results animation.
          # There are some other values that are supposed to be in there too,
          # but they don't seem to break anything when they're missing, so we
          # leave them alone.
          # If we just set `c` and `rr` to what the module expects them to be,
          # we can un-break the module the next time the user refreses the page.
          value['c'] = 1
          value['rr'] = true
          lessons[key] = value
        end
      end

      # If we didn't change anything, return the original data.
      return data_json unless found_bug

      # Otherwise, we need to put the new data back into the correct format.
      Honeycomb.start_span(name: 'xapi.fix_broken_suspend_data.pack') do
        unpacked_data['progress']['lessons'] = lessons
        unpacked_json = unpacked_data.to_json
        packed_data = @lzw_compress.eval("lzwCompress.pack('#{unpacked_json}')")
        data['d'] = packed_data
        return data.to_json
      end
    end
  rescue JSON::ParserError => e
    # If JSON.parse fails, just return the original data.
    data_json
  end
end
