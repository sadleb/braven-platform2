namespace :sync do
  desc "sync canvas grades"
  task canvas_grades: :environment do
    # Turn off debug logging, we don't need to see every SQL query.
    Rails.logger.level = Logger::INFO

    puts("### Running rake sync:canvas_grades - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

    service = SyncCanvasGrades.new
    service.run

    puts("### Done running rake sync:canvas_grades - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
  end
end
