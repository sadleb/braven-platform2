FactoryBot.define do
  factory :heroku_connect_record_type, class: 'heroku_connect/record_type' do
    sequence(:id)
    sequence(:sfid) { |i| "003a%011dXZX" % i }
    createddate { Time.now.utc.strftime("%F %T") }
    sequence(:name) {|i| "Some Record Type#{i}" }
  end
end
