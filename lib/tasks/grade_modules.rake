# This task might take some time to run, and use up a lot of memory, depending on how many Rise360ModuleInteraction
# records we need to process. We plan to schedule it to run once a day, in the middle of the night. If
# at some point we decide we need to calculate grades more frequently, we may need to optimize this
# task to be more memory- and/or time-efficient.

namespace :grade do
  desc "grade modules"
  task modules: :environment do
    Honeycomb.start_span(name: 'grade_modules.rake') do

      # Turn off debug logging, we don't need to see every SQL query.
      Rails.logger.level = Logger::INFO

      # Note: these puts (and all logs) don't make it to Papertrail b/c this is run in a one-off dyno.
      # Need to cutover to sidekiq if we want these logs to go there.

      puts("### Running rake grade:modules - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

      grade_modules_service = GradeModules.new
      grade_modules_service.run

      puts("### Done running rake grade:modules - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

    end
  rescue => e
    Sentry.capture_exception(e)
    raise # This goes off into never, never land unless you're running from the console
  end
end
