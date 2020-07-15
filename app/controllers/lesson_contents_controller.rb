require 'zip'

class LessonContentsController < ApplicationController
	def new
		@lesson_content = LessonContent.new
	end

	def create
		params.require([:state, :lesson_content_zipfile])

		lti_launch = LtiLaunch.current(params[:state])

		@lesson_content = LessonContent.new(lesson_content_params)
		@lesson_content.save

		# TODO
		#lesson_url = "https://platform-dev-file-uploads.s3.amazonaws.com/lessons/edrf8ftesbg6fwbo3qa70b7tmc52/index.html"
		@lesson_url = lesson_content_url(@lesson_content)
    	@deep_link_return_url, @jwt_response = helpers.lti_deep_link_response_message(lti_launch, @lesson_url)

		# Just render something
		# @filename = params[:lesson_content_zipfile]
		# @path = url_for(lesson_content.lesson_content_zipfile)
	end

	def show
		# TODO
		redirect_to "https://platform-dev-file-uploads.s3.amazonaws.com/lessons/edrf8ftesbg6fwbo3qa70b7tmc52/index.html"
	end

	def unzip_upload
		lesson_content = LessonContent.find(params[:id])
		@path = url_for(lesson_content.lesson_content_zipfile)

		@bucket_prefix = 'lessons/' + lesson_content.lesson_content_zipfile.key + '/'

		# Connect to AWS S3
	    credentials = Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"])
	    Aws.config.update({credentials: credentials})
	    s3 = Aws::S3::Resource.new(region: ENV["AWS_REGION"])
	    bucket = s3.bucket(ENV["AWS_S3_BUCKET"])

	    # Create a client so we can set permissions
	    client = Aws::S3::Client.new(region: ENV["AWS_REGION"])

		# Unzip
		# TODO: alternate: store .zip on disk with ActiveStorage 
		# since we don't really need to persist it instead of downloading
		@all_files = ''
		@all_dirs = ''
		lesson_content.lesson_content_zipfile.open do |file|
			@filepath = file.path
			Zip::File.open(file.path) do |zip_file|
				zip_file.each do |entry|
					if entry.file?
						@all_files +=  "#{entry.name}"

						# Upload the temporary file to the bucket
						# This gets us the right directory structure
						object_key = @bucket_prefix + "#{entry.name}"

						s3_obj = bucket.object(object_key)
						s3_obj.put(body: entry.get_input_stream.read)

						# TODO: Make each object public read as we're making it?
						client.put_object_acl( {
							acl: "public-read",
							bucket: ENV["AWS_S3_BUCKET"],
							key: object_key,
						})
						# Nope, don't do this, this upload the entire zipfile??? WTF.
						#s3_obj.put(body: entry.get_raw_input_stream)

						#entry.extract
						#content = entry.get_input_stream.read
						#puts content

						# This works, but it's unbearably slow
						# Extract and read input to temporary file
						# tempfile = Tempfile.new(File.basename(entry.name))
						# tempfile.binmode
						# tempfile.write(entry.get_input_stream.read)
						#s3_obj.upload_file(tempfile)
					elsif entry.directory? 
						@all_dirs += "#{entry.name}"
					end
				end
			end

			# Now that we've succeeded, make the bucket public
	    	client.put_bucket_acl({
  				acl: "public-read",
  				bucket: ENV["AWS_S3_BUCKET"],
			})
		end
	end

	private
    def lesson_content_params
    	params.permit(:lesson_content_zipfile)
    end

end
