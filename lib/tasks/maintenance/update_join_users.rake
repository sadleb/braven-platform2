# frozen_string_literal: true

namespace :maintenance do
  desc 'Run the join user update'
  task update_join_users: :environment do
    UpdateJoinUsers.new.run
  end
end
