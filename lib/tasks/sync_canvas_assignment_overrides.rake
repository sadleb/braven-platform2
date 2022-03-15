namespace :sync do
  desc "sync canvas assignment overrides"
  task canvas_assignment_overrides: :environment do
    Honeycomb.start_span(name: 'sync_canvas_assignment_overrides.rake') do
      # Turn off debug logging, we don't need to see every SQL query.
      Rails.logger.level = Logger::INFO

      # Note: these puts (and all logs) show up with app/scheduler.X in Papertrail.
      puts("### Running rake sync:canvas_assignment_overrides - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

      service = SyncCanvasAssignmentOverrides.new
      service.run

      puts("### Done running rake sync:canvas_assignment_overrides - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    end
  rescue => e
    puts(" ### Error running rake sync:canvas_assignment_overrides: #{e} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    Sentry.capture_exception(e)
    raise
  end
end
