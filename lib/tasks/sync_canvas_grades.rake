namespace :sync do
  desc "sync canvas grades"
  task canvas_grades: :environment do
    Honeycomb.start_span(name: 'sync_canvas_grades.rake') do

      # Turn off debug logging, we don't need to see every SQL query.
      Rails.logger.level = Logger::INFO

      # Note: these puts (and all logs) don't make it to Papertrail b/c this is run in a one-off dyno.
      # Need to cutover to sidekiq if we want these logs to go there.
      puts("### Running rake sync:canvas_grades - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

      service = SyncCanvasGrades.new
      service.run

      puts("### Done running rake sync:canvas_grades - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    end
  rescue => e
    Sentry.capture_exception(e)
    raise # This goes off into never, never land unless you're running from the console
  end
end
