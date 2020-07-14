class LessonContentsController < ApplicationController
	def new
		@lesson_content = LessonContent.new
	end

	def create
		@filename = params[:lesson_content_zipfile]
		@lesson_content = LessonContent.new(lesson_content_params)
		@lesson_content.save

	    # TODO: Access credentials from the shell environment instead
	    # credentials = Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"])
	    # Aws.config.update({credentials: credentials})
	    # s3 = Aws::S3::Resource.new(region: ENV["AWS_REGION"])
	    # bucket = s3.bucket(ENV["AWS_S3_BUCKET"])

	    # obj = bucket.object('unlock-your-hustle')
	    # obj.upload_file('unlock-your-hustle.zip')
	end

	private
    def lesson_content_params
    	params.permit(:lesson_content_zipfile)
    end
end
