class LtiLinkSelectionController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_admin!
  skip_before_action :verify_authenticity_token
  
  def index
  	# There's a way to configure this. See: 
  	# https://stackoverflow.com/questions/18445782/how-to-override-x-frame-options-for-a-controller-or-action-in-rails-4
  	response.headers["X-FRAME-OPTIONS"] = "ALLOW-FROM https://braven.instructure.com"

  	@canvas_user_id = "1234test!"

  	# Connect to S3 using .env configuration
  	credentials = Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"])
  	Aws.config.update({credentials: credentials})
  	s3 = Aws::S3::Resource.new(region: ENV["AWS_REGION"])
  	bucket = s3.bucket(ENV["AWS_S3_BUCKET"])

  	# TODO: Do an actual upload using the form in index.html.erb
  	# For now, just use a local thing and upload
  	# obj = bucket.object('unlock-your-hustle')
  	# obj.upload_file('unlock-your-hustle.zip')

  	# Now, try unzipping it locally
	Zip::File.open('unlock-your-hustle.zip') do |zip_file|
  	  zip_file.each do |file|
  	  	puts "Extracting #{file.name}"
  	  	filepath = File.join('tmp/unlock-your-hustle/', file.name)
  	  	FileUtils.mkdir_p(File.dirname(filepath))
  	  	zip_file.extract(file, filepath)
    	# obj = bucket.object('unlock-your-hustle-test/' + entry.name)
    	# obj.upload_file(entry.name)
  		end
  	end
  	# Upload recursively
  	# Delete all the local stuff
  	# Print the link

  end

  def create
  end
end
