# Add delayed_jobs that should be run on app startup in this file
Rails.configuration.after_initialize do

  unless Rails.env.test? # These are annoying when running specs. We should test the jobs directly anyway and not as part of app startup

    # Set delay to 0 in dev so that the Rails console doesn't log messages 30 seconds
    # later when you're in the middle of typing commands.
    lti_launch_cleanup_delay = (Rails.env.development? ? 0 : 30.seconds)
    CleanupLtiLaunchTableJob.set(wait: lti_launch_cleanup_delay).perform_later || Rails.logger.error('Failed to enqueue CleanupLtiLaunchTableJob')

  end
end
