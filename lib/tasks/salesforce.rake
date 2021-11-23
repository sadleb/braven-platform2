# Example Usage: bundle exec rake salesforce:sync_current_and_future
require 'salesforce_api'

namespace :salesforce do
  desc 'Update Platform and Canvas to match current/future Salesforce programs'
  task sync_current_and_future: :environment do
    Honeycomb.start_span(name: 'salesforce.rake.sync_current_and_future') do

      # Note: these puts (and all logs) show up with app/scheduler.X in Papertrail.
      puts("### Running rake salesforce:sync_current_and_future - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

      puts("    Fetching list of current/future programs with Accelerator course IDs - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
      program_data = SalesforceAPI.client.get_current_and_future_accelerator_programs
      program_ids = program_data.map { |program| program['Id'] }
      puts("    Found #{program_ids.count} programs - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

      program_ids.each do |program_id|

        Honeycomb.start_span(name: 'salesforce.rake.sync_salesforce_program') do
          puts("### Running Sync From Salesforce Program: #{program_id} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
          SyncSalesforceProgram.new(salesforce_program_id: program_id).run
          puts("    Done running Sync From Salesforce Program: #{program_id} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
        end

      rescue => e
        puts("    Error for Program #{program_id}: #{e} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
        puts("    Continuing to next Program. - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
        # Note: since the error propagated through the Honeycomb span it will be automatically added
        # in the error and error_detail fields. No need to add honeycomb stuff here.
        Sentry.capture_exception(e)
      end

      puts("### Done running rake salesforce:sync_current_and_future - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

    end # END Honeycomb.start_span

  # Just in case there is something outside of the actual sync that fails, like hitting the Salesforce API
  # to find out what to sync in the first place
  rescue => e2
    puts(" ### Error running rake salesforce:sync_current_and_future: #{e2} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    Sentry.capture_exception(e2)
    raise
  end
end
