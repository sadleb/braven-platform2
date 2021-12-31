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

    sequence(:uuid) { SecureRandom.uuid }
    sequence(:email) {|i| "test#{i}@example.com"}
    sequence(:first_name) { |i| names[i % names.size][0] }
    sequence(:last_name) { |i| names[i % names.size][1] }
    sequence(:canvas_user_id)

    # Note: the salesforce IDs below need to be 18 chars and unique. It's important to use a slight
    # variation of the pattern for different factories to avoid collisions. We allow want to allow as
    # big of an integer as possible so it doesn't overflow. Right now we can go up to 11 character digits,
    # so this won't start failing until we create 100 billion users as part of running our specs.

    factory :unregistered_user do
      sequence(:salesforce_id) { |i| "003x%011dAAQ" % i }
    end

    factory :registered_user do
      sequence(:password) { |i| "Val!dPassword#{i}" }
      sequence(:salesforce_id) { |i| "003y%011dAAZ" % i }
      confirmed_at { DateTime.now }
      registered_at { DateTime.now }

      factory :unconfirmed_user do
        confirmed_at { nil }
      end

      # A user whose email was changed and it needs to be reconfirmed
      # before it can be used
      factory :reconfirmation_user do
        confirmed_at { 1.day.ago }
        sequence(:confirmation_token) { |i| "13m9XK%09d" % i }
        unconfirmed_email { "#{email}.unconfirmed" }
      end

      # section only used in child factory callbacks.
      transient do
        section { build(:section) }
      end

      factory :fellow_user do
        after :create do |user, options|
          user.add_role RoleConstants::STUDENT_ENROLLMENT, options.section
        end

        factory :linked_in_user do
          linked_in_state { '' }
        end

        factory :peer_user do
          # DEPRECATED: You can just use fellow_user instead now that
          # canvas_user_id is un-hardcoded.
        end
      end

      factory :ta_user do
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
        after :create do |user, options|
          user.add_role RoleConstants::STUDENT_ENROLLMENT, options.section
        end
      end
    end

  end
end
