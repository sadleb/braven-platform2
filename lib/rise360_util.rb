# frozen_string_literal: true
require 'nokogiri'

# Provides helper methods to unzip, publish, and launch Rise360Module
# and CourseResource on AWS S3
class Rise360Util

  S3_OBJECT_PREFIX = "lessons"
  INDEX_FILE = "index.html"
  TINCAN_XML_FILE = "tincan.xml"
  QUIZ_QUESTION_XPATH = '//tincan/activities/activity[@type="http://adlnet.gov/expapi/activities/cmi.interaction"]'
  COURSE_XPATH = '//tincan/activities/activity[@type="http://adlnet.gov/expapi/activities/course"]'

  # The full request_uri, aka path (including query params) to be able to launch
  # the Rise360 Module. 
  #
  # The "filekey" is the "key" attribute of an ActiveStorage zipfile.
  # Aka the name of the zipfile on S3.
  def self.launch_path(filekey, bucket = nil)
    bucket = AwsS3Bucket.new unless bucket
    aws_url = bucket.object(s3_object_key(filekey, INDEX_FILE)).public_url
    URI(aws_url).request_uri
  end

  # Gets a presigned_url valid for an hour that will be authenticated
  # if you make a GET request to it.
  #
  # See: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_url-instance_method
  def self.presigned_url(launch_path)
    bucket = AwsS3Bucket.new
    launch_path.slice!(0) # Remove leading slash
    bucket.object(launch_path).presigned_url(:get, expires_in: 1.hour.to_i)
  end

  # Publishes an ActiveStorage zipfile (with a "key" attribute)
  # to S3 such that calling Rise360Util.launch_url(key)
  # will return the publicly accessible URL for it's index.html
  def self.publish(zipfile)
      bucket = AwsS3Bucket.new

      zipfile.open do |file|
        Honeycomb.start_span(name: 'Rise360Util.publish.zipfile') do |span|
          span.add_field('app.zipfile.path', file.path)
          span.add_field('app.zipfile.size', file.size)

          Zip::File.open(file.path) do |zip_file|
            zip_file.each do |entry|
              next unless entry.file?
              s3_object = bucket.object(s3_object_key(zipfile.key, entry.name))
              s3_object.put({
                  body: entry.get_input_stream.read,
              })
            end
          end
        end
      end

      launch_path(zipfile.key, bucket)
  end

  # Pulls down the tincan.xml from S3 and updates the record with extra context.
  def self.update_metadata!(rise360_module, bucket = nil)
    # TODO: in a future iteration we'll want to generate pre-signed URLs with expirations on
    # them so that our content doesn't get leaked for anyone to access. Right now the bucket is public
    # but we'll want to lock it down.
    bucket = AwsS3Bucket.new unless bucket
    tincan_xml = bucket.object(s3_object_key(rise360_module.rise360_zipfile.key, TINCAN_XML_FILE)).get()['body'].read()

    # Parse tincan.xml and extract what we need.
    tincan_data = Nokogiri::XML(tincan_xml)
    # See https://stackoverflow.com/questions/4690737/nokogiri-xpath-namespace-query.
    tincan_data.remove_namespaces!
    rise360_module.update!(
      quiz_questions: tincan_data.xpath(QUIZ_QUESTION_XPATH).count,
      activity_id: tincan_data.xpath(COURSE_XPATH).first['id'],
    )
  rescue Exception => e
    Rails.logger.error("Could not update Rise360Module metadata: #{rise360_module}")
    Rails.logger.error("  Error: #{e}")
    Honeycomb.add_field('error', e.class.name)
    Honeycomb.add_field('error_detail', e.message)
    Honeycomb.add_field('rise360_module.id', rise360_module.id)
  end

  class << self
    private
    # Return an S3 object key for a filename in the zip
    # relative to the filekey (aka the zipfile key)
    def s3_object_key(filekey, filename)
      [ S3_OBJECT_PREFIX, filekey, filename ].join("/")
    end
  
  end

  # Wrapper for an AWS S3 bucket. Takes care of authentication.
  class AwsS3Bucket
    # Calls "object" on the authenticated bucket.
    def object(*args)
      @bucket ||= begin
        credentials = Aws::Credentials.new(Rails.application.secrets.aws_access_key, Rails.application.secrets.aws_secret_access_key)
        Aws.config.update({credentials: credentials})
        Aws::S3::Resource.new(region: Rails.application.secrets.aws_region).bucket(Rails.application.secrets.aws_files_bucket)
      end
      @bucket.object(*args)
    end

  end
end

