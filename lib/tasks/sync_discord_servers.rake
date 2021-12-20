namespace :sync do
  desc "sync discord server info"
  task discord_servers: :environment do
    Honeycomb.start_span(name: 'sync_discord_servers.rake') do

      # Turn off debug logging, we don't need to see every SQL query.
      Rails.logger.level = Logger::INFO

      # Note: these puts (and all logs) show up with app/scheduler.X in Papertrail.
      puts("### Running rake sync:discord_servers - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")

      service = SyncDiscordServers.new
      service.run

      puts("### Done running rake sync:discord_servers - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    end
  rescue => e
    puts(" ### Error running rake sync:discord_servers: #{e} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    Sentry.capture_exception(e)
    raise
  end
end
