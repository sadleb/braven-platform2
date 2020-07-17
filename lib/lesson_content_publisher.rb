# Provides helper methods to unzip, publish, and launch LessonContent
# on AWS S3
class LessonContentPublisher

  S3_OBJECT_PREFIX = "lessons".freeze
  INDEX_FILE = "index.html".freeze

  # Publishes an ActiveStorage zipfile (with a "key" attribute)
  # to S3 such that calling LessonContentPublisher.launch_url(key)
  # will return the publicly accessible URL for it's index.html
  def self.publish(zipfile)
    Rails.logger.debug("Unzipping #{zipfile}")
    unzip_to_s3(zipfile)
  end

  # Publicly accessible URL for the lesson
  # The "filekey" is the "key" attribute of an ActiveStorage zipfile.
  # Aka the name of the zipfile on S3.
  def self.launch_url(filekey, bucket = nil)
    bucket = AwsS3Bucket.new unless bucket
    bucket.object(s3_object_key(filekey, INDEX_FILE)).public_url
  end

  class << self
    private

    def unzip_to_s3(zipfile)
      filekey=zipfile.key
      bucket = AwsS3Bucket.new

      # Save all the object keys and file input streams before we start threading
      # If we don't do this sequentially before threading, the threads can start
      # up and try to upload before the file streams are available
      files = {}
      zipfile.open do |file|
        Zip::File.open(file.path) do |zip_file|
          zip_file.each do |entry|
            next unless entry.file?
            files[s3_object_key(filekey, entry.name)] = entry.get_input_stream
          end
        end
      end
  
      # Thread per file to upload
      # TODO: Would this be faster if we created fewer threads and treated the array as a work
      # queue? But then there's mutex to synchronize over work
      # https://gist.github.com/fleveque/816dba802527eada56ab
      threads = []
      files.each do |key, input|
        threads << Thread.new {
          s3_object = bucket.object(key)
          s3_object.put({
              acl: "public-read",
              body: input.read,
          })
        }
      end
  
      # Wait for them to finish
      threads.each { |t| t.join }

      launch_url(INDEX_FILE, bucket)
    end
  
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

