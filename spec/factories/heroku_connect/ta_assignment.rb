FactoryBot.define do
  factory :heroku_connect_ta_assignment, class: 'heroku_connect/ta_assignment' do
    sequence(:id)
    sequence(:sfid) { |i| "003a%011dAZQ" % i }
    createddate { Time.now.utc.strftime("%F %T") }
    isdeleted { false }
    sequence(:name) {|i| "TA Assignment Name#{i}" }

    association :program, factory: :heroku_connect_program
    association :fellow_participant, factory: :heroku_connect_fellow_participant
    association :ta_participant, factory: :heroku_connect_ta_participant
  end
end
