class LtiLinkSelectionController < ApplicationController
  # Non-standard controller without normal CRUD methods. Disable the convenience module.
  def dry_crud_enabled?() false end

  def new
  	# There's a way to configure this. See: 
  	# https://stackoverflow.com/questions/18445782/how-to-override-x-frame-options-for-a-controller-or-action-in-rails-4
  	# response.headers["X-FRAME-OPTIONS"] = "ALLOW-FROM https://braven.instructure.com"

    # Create a new course
    @course_content = CourseContent.new
  end

  def create
    @filename = params[:course_content_zipfile]
    @course_content = CourseContent.new(course_content_params)
    @course_content.save

    # TODO: Access credentials from the shell environment instead
    # credentials = Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"])
    # Aws.config.update({credentials: credentials})
    # s3 = Aws::S3::Resource.new(region: ENV["AWS_REGION"])
    # bucket = s3.bucket(ENV["AWS_S3_BUCKET"])

    # obj = bucket.object('unlock-your-hustle')
    # obj.upload_file('unlock-your-hustle.zip')
  end

  private
    def course_content_params
      params.permit(:course_content_zipfile)
    end
end
