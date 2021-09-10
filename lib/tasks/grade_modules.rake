# This task might take some time to run, and use up a lot of memory, depending on how many Rise360ModuleInteraction
# records we need to process. We plan to schedule it to run once a day, in the middle of the night. If
# at some point we decide we need to calculate grades more frequently, we may need to optimize this
# task to be more memory- and/or time-efficient.

namespace :grade do
  desc "grade all Rise360 modules"
  task modules: :environment do
    Honeycomb.start_span(name: 'grade_modules.rake') do

      # Turn off debug logging, we don't need to see every SQL query.
      Rails.logger.level = Logger::INFO

      # Note: these puts (and all logs) show up with app/scheduler.X in Papertrail.
      puts("### Running rake grade:modules - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

      grade_modules_service = GradeRise360Modules.new
      grade_modules_service.run

      puts("### Done running rake grade:modules - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

    end
  rescue => e
    puts(" ### Error running rake grade:modules: #{e} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    Sentry.capture_exception(e)
    raise
  end
end
