# Example Usage: bundle exec rake salesforce:sync_current_and_future
require 'salesforce_api'

namespace :salesforce do
  desc 'Update Platform and Canvas to match current/future Salesforce programs'
  task sync_current_and_future: :environment do
    puts("### Fetching list of current/future programs with Accelerator course IDs - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    program_data = SalesforceAPI.client.get_current_and_future_accelerator_programs
    program_ids = program_data['records'].map { |program| program['Id'] }
    puts("    Found #{program_ids.count} programs - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

    program_ids.each do |program_id|
      puts("### Running Sync From Salesforce Program: #{program_id} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
      SyncPortalEnrollmentsForProgram.new(salesforce_program_id: program_id).run
      puts("    Done running Sync From Salesforce Program: #{program_id} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    end
  end

end
