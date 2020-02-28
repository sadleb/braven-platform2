FactoryBot.define do
  factory :rubric_row_rating do
    description { 'Award this many points if blah' }
    points_value { 10 }

    rubric_row
  end
end

