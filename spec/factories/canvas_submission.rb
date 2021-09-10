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
    sequence(:grader_id)
    initialize_with { attributes.stringify_keys }
  end
end

# TODO: create factories for these examples:

# Never opened
# {"id"=>20156, "body"=>nil, "url"=>nil, "grade"=>nil, "score"=>nil, "submitted_at"=>nil, "assignment_id"=>2628, "user_id"=>573, "submission_type"=>nil, "workflow_state"=>"unsubmitted", "grade_matches_current_submission"=>true, "graded_at"=>nil, "grader_id"=>nil, "attempt"=>nil, "cached_due_date"=>nil, "excused"=>nil, "late_policy_status"=>nil, "points_deducted"=>nil, "grading_period_id"=>nil, "extra_attempts"=>nil, "posted_at"=>nil, "late"=>false, "missing"=>false, "seconds_late"=>0, "entered_grade"=>nil, "entered_score"=>nil, "preview_url"=>"https://braven.instructure.com/courses/48/assignments/2628/submissions/573?preview=1&version=0", "anonymous_id"=>"CZN9p"}


# Opened, not yet auto-graded
# {"id"=>20156, "body"=>nil, "url"=>"https://braven.instructure.com/courses/48/external_tools/retrieve?assignment_id=2628&url=https%3A%2F%2Fplatformweb%2Frise360_module_grades%2F29", "grade"=>nil, "score"=>nil, "submitted_at"=>"2021-08-12T21:18:44Z", "assignment_id"=>2628, "user_id"=>573, "submission_type"=>"basic_lti_launch", "workflow_state"=>"submitted", "grade_matches_current_submission"=>true, "graded_at"=>nil, "grader_id"=>nil, "attempt"=>1, "cached_due_date"=>nil, "excused"=>nil, "late_policy_status"=>nil, "points_deducted"=>nil, "grading_period_id"=>nil, "extra_attempts"=>nil, "posted_at"=>nil, "late"=>false, "missing"=>false, "seconds_late"=>0, "entered_grade"=>nil, "entered_score"=>nil, "preview_url"=>"https://braven.instructure.com/courses/48/assignments/2628/submissions/573?preview=1&version=1", "external_tool_url"=>"https://platformweb/rise360_module_grades/29", "anonymous_id"=>"CZN9p"}


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

