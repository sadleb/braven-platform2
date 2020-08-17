Rails.configuration.after_initialize do

  # Add delayed_jobs that should be run on app startup here:
  CleanupLtiLaunchTableJob.set(wait: 30.seconds).perform_later || Rails.logger.error('Failed to enqueue CleanupLtiLaunchTableJob')

end
