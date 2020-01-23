FactoryBot.define do
  factory :user do
    transient do
      names do
        [
          ['Aaron', 'Anderson'], ['Anthony', 'Anderson'], ['Barry', 'Boswick'], ['Bill', 'Boswick'], 
          ['Bob', 'Boswick'], ['Cara', 'Clark'], ['Candice', 'Clark'], ['Carmen', 'Clark'], 
          ['Diana', 'Davis'], ['Daisy', 'Davis'], ['Deirdre', 'Davis'], ['Fred', 'Fox'], 
          ['Fran', 'Fox'], ['Gertie', 'Gray'], ['Greg', 'Gray'], ['Henry', 'Hill'], 
          ['Harrieta', 'Hill'], ['Harvey', 'Hill'], ['Jack', 'Jones'], ['Jenny', 'Jones'], 
          ['John', 'Jones'], ['Jeff', 'Jones']
        ]
      end
    end
    
    sequence(:email) {|i| "test#{i}@example.com"}
    sequence(:first_name) { |i| names[i % names.size][0] }
    sequence(:last_name) { |i| names[i % names.size][1] }
    admin { false }
  end
end
