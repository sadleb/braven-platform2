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
    
    factory :registered_user do
      sequence(:password) { |i| "password#{i}" }
      sequence(:salesforce_id) { |i| "003#{i}100001iyv8IAAQ" }
      confirmed_at { DateTime.now }

      factory :unconfirmed_user do
        confirmed_at { nil }
      end

      # section only used in child factory callbacks.
      transient do
        section { build(:section) }
      end

      factory :fellow_user do
        sequence(:canvas_user_id)
        after :create do |user, options|
          user.add_role RoleConstants::STUDENT_ENROLLMENT, options.section
        end

        factory :linked_in_user do
          linked_in_state { '' }
        end

        factory :peer_user do
          sequence(:canvas_user_id)
        end
      end

      factory :ta_user do
        sequence(:canvas_user_id)
        after :create do |user, options|
          user.add_role RoleConstants::TA_ENROLLMENT, options.section
        end
      end

      factory :admin_user do
        after :create do |user|
          user.add_role :admin
        end
      end

      factory :lc_playbook_user do
        sequence(:canvas_user_id)
        after :create do |user, options|
          user.add_role RoleConstants::STUDENT_ENROLLMENT, options.section
        end
      end
    end

  end
end
