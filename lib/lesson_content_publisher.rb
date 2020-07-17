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
    # Save all the object keys and file input streams before we start threading
    # If we don't do this sequentially before threading, the threads can start
    # up and try to upload before the file streams are available
    files = {}
    zipfile.open do |file|
      Zip::File.open(file.path) do |zip_file|
        zip_file.each do |entry|
          next unless entry.file?
          files[s3_object_key(entry.name)] = entry.get_input_stream
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
  end

  # Return an S3 object key for a file in the zip
  # for a relative filepath in the zipfile
  def s3_object_key(filename)
    [ S3_OBJECT_PREFIX, @zipfilekey, filename ].join("/")
  end

  def bucket
    @bucket ||= begin
      credentials = Aws::Credentials.new(Rails.application.secrets.aws_access_key, Rails.application.secrets.aws_secret_access_key)
      Aws.config.update({credentials: credentials})
      Aws::S3::Resource.new(region: Rails.application.secrets.aws_region).bucket(Rails.application.secrets.aws_files_bucket)
    end
  end

end

