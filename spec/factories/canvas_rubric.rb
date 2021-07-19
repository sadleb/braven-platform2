FactoryBot.define do

  # Represents the rubric_settings returned in an Assignment from the canvas API
  factory :canvas_rubric_settings, class: Hash do
    sequence(:id) 
    sequence(:title) { |i| "Rubric Title#{i}" } 
    sequence(:points_possible) {|i| i.to_f }
    free_form_criterion_comments { true }
    hide_score_total { false }
    hide_points { false }

    # Represents a rubric returned from the canvas API
    factory :canvas_rubric, class: Hash do
      skip_create # This isn't stored in the DB.
  
      transient do
        sequence(:course_id)
      end
      context_id { course_id }
      context_type { 'Course' } 
      reusable { false }
      read_only { false }
      data { [ build(:canvas_rubric_data) ] }
  
      transient do
        sequence(:assignment_id)
      end
  
      factory :canvas_rubric_with_association do
        associations { [build(:canvas_rubric_association, rubric_id: id, association_id: assignment_id)] } 
      end
  
    end

    initialize_with { attributes.stringify_keys }
  end

  # Represents a rubric association returned from the canvas API
  factory :canvas_rubric_association, class: Hash do
    skip_create # This isn't stored in the DB.

    sequence(:id)
    sequence(:rubric_id) 
    sequence(:association_id) # ID of Assignment if that's the type
    association_type { 'Assignment' }
    use_for_grading { true }
    summary_data { nil }
    purpose { 'grading' }
    hide_score_total { false }
    hide_points { false }
    hide_outcome_results { false }

    initialize_with { attributes.stringify_keys }
  end

  factory :canvas_rubric_data, class: Hash do
    skip_create # This isn't stored in the DB.

    sequence(:id) { |i| "_#{i}" } # These IDs are prefixed with an underscore. Not sure why.
    sequence(:description) { |i| "Rubric Row#{i}" }
    long_description { '' }
    sequence(:points) { |i| i.to_f }
    criterion_use_range { false }
    ratings { [
      build(:canvas_rubric_rating, description: 'No Marks', points: 0.0, criterion_id: id),
      build(:canvas_rubric_rating, description: 'Full Marks', points: points, criterion_id: id)
    ] }

    initialize_with { attributes.stringify_keys }
  end

  factory :canvas_rubric_rating, class: Hash do
    skip_create # This isn't stored in the DB.

    sequence(:id) { |i| "_#{i}" } # These IDs are prefixed with an underscore. Not sure why.
    sequence(:criterion_id) { |i| "_#{i}" }
    sequence(:description) { |i| "#{i} Marks" }
    long_description { '' }
    sequence(:points) { |i| i.to_f }
    
    initialize_with { attributes.stringify_keys }
  end
end

# Example
#{
#  // the ID of the rubric
#  "id": 1,
#  // title of the rubric
#  "title": "some title",
#  // the context owning the rubric
#  "context_id": 1,
#  "context_type": "Course",
#  "points_possible": 10.0,
#  "reusable": false,
#  "read_only": true,
#  // whether or not free-form comments are used
#  "free_form_criterion_comments": true,
#  "hide_score_total": true,
#  // An array with all of this Rubric's grading Criteria
#  "data": null,
#  // If an assessment type is included in the 'include' parameter, includes an
#  // array of rubric assessment objects for a given rubric, based on the
#  // assessment type requested. If the user does not request an assessment type
#  // this key will be absent.
#  "assessments": null,
#  // If an association type is included in the 'include' parameter, includes an
#  // array of rubric association objects for a given rubric, based on the
#  // association type requested. If the user does not request an association type
#  // this key will be absent.
#  "associations": null
#}
