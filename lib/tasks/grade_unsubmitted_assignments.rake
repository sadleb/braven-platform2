namespace :grade do
  desc "set past due missing project grades to zero"
  task grade_unsubmitted_assignments: :environment do
    Honeycomb.start_span(name: 'grade_unsubmitted_assignments.rake') do

      # Turn off debug logging, we don't need to see every SQL query.
      Rails.logger.level = Logger::INFO

      # Note: these puts (and all logs) show up with app/scheduler.X in Papertrail.
      puts("### Running rake grade:grade_unsubmitted_assignments - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

      grade_unsubmitted_assignments_service = GradeUnsubmittedAssignments.new
      grade_unsubmitted_assignments_service.run

      puts("### Done running rake grade:grade_unsubmitted_assignments - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

    end
  rescue => e
    puts(" ### Error running rake grade:grade_unsubmitted_assignments: #{e} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    Sentry.capture_exception(e)
    raise
  end
end