namespace :maintenance do
  desc "delete old records in tickets tables"
  task :delete_old_tickets, [:tablename, :num_days] => :environment do |_, args|
    tbl = args[:tablename]
    num = args[:num_days].to_i
    sql = "DELETE FROM #{tbl} WHERE created_on < NOW() - interval '#{num} days'"
    ActiveRecord::Base.connection.execute(sql)
  end
end
