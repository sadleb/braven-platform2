# Represents the contents of a Canvas module, e.g. a Rise 360 course
class LessonContent < ApplicationRecord
  # Rise 360 lesson zipfile
  has_one_attached :lesson_content_zipfile

  S3_OBJECT_PREFIX = "lessons".freeze
  INDEX_FILE = "index.html".freeze

  # Publicly accessible URL for the lesson
  def get_index_url
    bucket.object(s3_object_key(INDEX_FILE)).public_url
  end

  # Return an S3 object key for a file in the zip
  # for a relative filepath in lesson_content_zipfile
  def s3_object_key(filename)
    [ S3_OBJECT_PREFIX, self.lesson_content_zipfile.key, filename ].join("/")
  end

  # Extract the lesson_content_zipfile and store it on S3
  # Return index to access content
  def extract
    return get_index_url unless !bucket.object(s3_object_key(INDEX_FILE)).exists?

    # Extract the zipfile
    credentials = Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"])
    Aws.config.update({credentials: credentials})
    bucket = Aws::S3::Resource.new(region: ENV["AWS_REGION"]).bucket(ENV["AWS_S3_BUCKET"])

    self.lesson_content_zipfile.open do |file|
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

    get_index_url
  end

  # Return S3 bucket
  private
  def bucket
    credentials = Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"])
    Aws.config.update({credentials: credentials})
    s3 = Aws::S3::Resource.new(region: ENV["AWS_REGION"])
    s3.bucket(ENV["AWS_S3_BUCKET"])
  end
end
