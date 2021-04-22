namespace :salesforce do

  desc 'Update Platform and Canvas to match the Salesforce Program'
  # Example Usage: bundle exec rake salesforce:sync_from_salesforce_program[a2Y1J000000YpQFUA0]
  task :sync_from_salesforce_program, [:program_id] => :environment do |_, args|
    program_id = args[:program_id]
    puts("### Running Sync From Salesforce Program: #{program_id} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    require 'sync_portal_enrollments_for_program'
    SyncPortalEnrollmentsForProgram.new(salesforce_program_id: program_id).run
    puts("    Done running Sync From Salesforce Program: #{program_id} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
  end

end
