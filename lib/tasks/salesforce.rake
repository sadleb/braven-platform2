namespace :salesforce do

  desc 'Provision Enrolled Participants from Salesforce into Canvas'
  # Example Usage: bundle exec rake salesforce:sync_to_lms[71]
  task :sync_to_lms, [:course_id] => :environment do |_, args|
    course_id = args[:course_id].to_i
    puts("### Running Sync To LMS for #{course_id} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    require 'sync_to_lms'
    SyncToLMS.new.execute(course_id)
    puts("    Done running Sync To LMS for #{course_id} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
  end

end
