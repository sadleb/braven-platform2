FactoryBot.define do
  # Represents a submission returned from the canvas API
  # https://canvas.instructure.com/doc/api/submissions.htm
  #
  # This is meant to be built with FactoryBot.json(:canvas_submission)
  factory :canvas_submission, class: Hash do
    skip_create # This isn't stored in the DB.
    sequence(:id)
    sequence(:assignment_id)
    sequence(:user_id)
    grader_id { nil }
    graded_at { nil }
    submitted_at { nil }
    score { nil }
    grade { nil }
    # Default to a future due date. Override if necessary
    cached_due_date { (Time.now + 1.day).utc.iso8601 }

    # Represents a canvas_submission for an assignment that's never been
    # submitted by the user (or the auto-grading code)
    factory :canvas_submission_placeholder, class: Hash do
      skip_create # This isn't stored in the DB.
      workflow_state { 'unsubmitted' }
      submission_type { nil }
      preview_url { 'https://braven.instructure.com/courses/48/assignments/2628/submissions/573?preview=1&version=0' }
    end

    # Represents a canvas_submission for a Rise360Module assignment that's been opened but
    # never auto-graded
    factory :canvas_submission_rise360_module_opened, class: Hash do
      skip_create # This isn't stored in the DB.
      workflow_state { 'submitted' }
      url { 'https://braven.instructure.com/courses/48/external_tools/retrieve?assignment_id=2628&url=https%3A%2F%2Fplatformweb%2Frise360_module_grades%2F29' }
      submitted_at { (Time.now - 1.day).utc.iso8601 }
      submission_type { 'basic_lti_launch' }
      external_tool_url { 'https://platformweb/rise360_module_grades/29' }
    end

    initialize_with { attributes.stringify_keys }
  end
end

# Example
#{
#    "anonymous_id": "NtN8d",
#    "assignment_id": 2629,
#    "attempt": 1,
#    "body": null,
#    "cached_due_date": null,
#    "entered_grade": "3.3",
#    "entered_score": 3.3,
#    "excused": false,
#    "external_tool_url": "https://platformweb/rise360_module_grades/8",
#    "extra_attempts": null,
#    "grade": "3.3",
#    "grade_matches_current_submission": true,
#    "graded_at": "2021-05-04T11:49:50Z",
#    "grader_id": 342,
#    "grading_period_id": null,
#    "id": 7493,
#    "late": false,
#    "late_policy_status": null,
#    "missing": false,
#    "points_deducted": null,
#    "posted_at": "2021-05-04T11:18:03Z",
#    "preview_url": "https://braven.instructure.com/courses/48/assignments/2629/submissions/335?preview=1&version=6",
#    "score": 3.3,
#    "seconds_late": 0,
#    "submission_type": "basic_lti_launch",
#    "submitted_at": "2021-05-04T09:52:06Z",
#    "url": "https://braven.instructure.com/courses/48/external_tools/retrieve?assignment_id=2629&url=https%3A%2F%2Fplatformweb%2Frise360_module_grades%2F8",
#    "user_id": 335,
#    "workflow_state": "graded"
#}

