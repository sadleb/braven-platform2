class LessonContentPublisher

  S3_OBJECT_PREFIX = "lessons".freeze
  INDEX_FILE = "index.html".freeze

  # The "key" attribute of an ActiveStorage zipfile. This the name of the zipfile on S3.
  def initialize(zipfilekey)
    @zipfilekey = zipfilekey
  end

  def publish(zipfile)
    Rails.logger.debug("Unzipping #{zipfile}")
    unzip_to_s3(zipfile)
    launch_url
  end

  # Publicly accessible URL for the lesson
  def launch_url
    bucket.object(s3_object_key(INDEX_FILE)).public_url
  end

  def is_published?
    # TODO: Is there a more robust way to check instead of querying the S3 path everytime?
    # https://app.asana.com/0/1174274412967132/1184800386160068
    bucket.object(s3_object_key(INDEX_FILE)).exists?
  end

  private

  def unzip_to_s3(zipfile)
   zipfile.open do |file|
      Zip::File.open(file.path) do |zip_file|
        zip_file.each do |entry|
          next unless entry.file?
          s3_object = bucket.object(s3_object_key(entry.name))
          s3_object.put({
              acl: "public-read",
              body: entry.get_input_stream.read,
          })
        end
      end
    end
  end

  # Return an S3 object key for a file in the zip
  # for a relative filepath in the zipfile
  def s3_object_key(filename)
    tmp = [ S3_OBJECT_PREFIX, @zipfilekey, filename ].join("/")

# TODO: remove me
puts "### processing s3_object_key = #{tmp}"

    tmp
  end

  def bucket
    credentials = Aws::Credentials.new(Rails.application.secrets.aws_access_key, Rails.application.secrets.aws_secret_access_key)
    Aws.config.update({credentials: credentials})
    Aws::S3::Resource.new(region: Rails.application.secrets.aws_region).bucket(Rails.application.secrets.aws_files_bucket)
  end

end

