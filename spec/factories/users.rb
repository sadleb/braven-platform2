FactoryBot.define do
  factory :user do
    id { contact.user_id }
    sequence(:uuid) { SecureRandom.uuid }
    email { contact.email }
    first_name { contact.first_name }
    last_name { contact.last_name }
    canvas_user_id { contact.canvas_user_id }
    salesforce_id { contact.sfid }

    transient do
      # If you need a User to match a HerokuConnect::Contact,
      # pass that in when creating one of these factories
      contact { build :heroku_connect_contact }
    end

    factory :unregistered_user do

      factory :unregistered_user_with_invalid_signup_token do
        sequence(:signup_token) {|i| "token#{i}" }
        sequence(:signup_token_sent_at) { 1.year.ago }
      end

      factory :unregistered_user_with_valid_signup_token do
        sequence(:signup_token) {|i| "token#{i}" }
        sequence(:signup_token_sent_at) { DateTime.now }
      end
    end

    factory :registered_user do
      sequence(:password) { |i| "Val!dPassword#{i}" }
      confirmed_at { DateTime.now }
      registered_at { DateTime.now }
      signup_token_sent_at { DateTime.now }

      # section only used in child factory callbacks.
      transient do
        section { build(:cohort_section) }
        lc_playbook_section { build(:cohort_schedule_section) }
      end

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
        transient do
          accelerator_section { build(:ta_section) }
          lc_playbook_section { build(:ta_section) }
        end

        after :create do |user, options|
          user.add_role RoleConstants::TA_ENROLLMENT, options.accelerator_section
          user.add_role RoleConstants::STUDENT_ENROLLMENT, options.lc_playbook_section
        end
      end

      factory :lc_user do
        transient do
          accelerator_section { build(:ta_section) }
          lc_playbook_section { build(:ta_section) }
        end

        after :create do |user, options|
          user.add_role RoleConstants::TA_ENROLLMENT, options.accelerator_section
          user.add_role RoleConstants::STUDENT_ENROLLMENT, options.lc_playbook_section
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
