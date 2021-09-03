# Example Usage: bundle exec rake salesforce:sync_current_and_future
require 'salesforce_api'

namespace :salesforce do
  desc 'Update Platform and Canvas to match current/future Salesforce programs'
  task sync_current_and_future: :environment do
    Honeycomb.start_span(name: 'salesforce.rake.sync_current_and_future') do

      # Note: these puts (and all logs) don't make it to Papertrail b/c this is run in a one-off dyno.
      # Need to cutover to sidekiq if we want these logs to go there.
      puts("### Fetching list of current/future programs with Accelerator course IDs - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

      program_data = SalesforceAPI.client.get_current_and_future_accelerator_programs
      program_ids = program_data.map { |program| program['Id'] }
      puts("    Found #{program_ids.count} programs - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

      program_ids.each do |program_id|

        Honeycomb.start_span(name: 'salesforce.rake.sync_portal_enrollments_for_program') do
          puts("### Running Sync From Salesforce Program: #{program_id} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
          SyncPortalEnrollmentsForProgram.new(salesforce_program_id: program_id).run
          puts("    Done running Sync From Salesforce Program: #{program_id} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
        end

      rescue => e
        puts("    Error: #{e} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
        puts("    Continuing to next Program. - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
        # Note: since the error propagated through the Honeycomb span it will be automatically added
        # in the error and error_detail fields.
        Sentry.capture_exception(e)
      end

    end # END Honeycomb.start_span

  # Just in case there is something outside of the actual sync that fails, like hitting the Salesforce API
  rescue => e2
    Sentry.capture_exception(e2)
    raise # This goes off into never, never land unless you're running from the console
  end
end
