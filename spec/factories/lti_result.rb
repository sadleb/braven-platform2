# Represents a Result returned for a score created using the LtiAdvantageAPI
#
# See: https://canvas.instructure.com/doc/api/result.html
FactoryBot.define do

  # Create JSON with FactoryBot.json(:lti_score)
  factory :lti_result, class: Hash do

  transient do
    sequence(:canvas_course_id)
    sequence(:line_item_id)
    submission_data { 'https://some.lti.launch.url.such.as/waivers/completed' }
    submission_type { 'basic_lti_launch' }
  end

    sequence(:id) { |i| "#{scoreOf}/results/#{i}" }
    scoreOf { "https://the.braven.canvas.server.com/api/lti/courses/#{canvas_course_id}/line_items/#{line_item_id}" }
    sequence(:userId) { |i| "743bf861-0114-441a-864a-95f20ad3d39#{i}" } # doc's say this can be Canvas user_id, but in practice it's the LTI user id
    resultScore { 100.0 }
    resultMaximum { 100.0 }
    comment { nil }

    initialize_with { attributes.stringify_keys }

    after :build do |the_object, evaluator|
      # This isn't shown in the API docs, but the extension key with the submission
      # data is sent back if it was specified when calling create_score which hits:
      # https://canvas.instructure.com/doc/api/score.html#method.lti/ims/scores.create
      the_object['https://canvas.instructure.com/lti/submission'] = {
        'new_submission' => true,
        'submission_data' => evaluator.submission_data,
        'submission_type' => evaluator.submission_type
      }
    end

  end

end


# Example:
# {
#   "id"=>"https://braven.instructure.com/api/lti/courses/233/line_items/674/results/178",
#   "scoreOf"=>"https://braven.instructure.com/api/lti/courses/233/line_items/674",
#    "userId"=>"743bf861-0114-441a-864a-95f20ad3d397",
#    "resultScore"=>100.0,
#    "resultMaximum"=>100.0,
#    "https://canvas.instructure.com/lti/submission"=>{
#      "new_submission"=>true,
#      "submission_data"=>"https://platformweb/waivers/completed",
#      "submission_type"=>"basic_lti_launch"
#    }
# }



