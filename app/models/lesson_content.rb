# Represents the contents of a Canvas module, e.g. a Rise 360 course
class LessonContent < ApplicationRecord
  # Rise 360 lesson zipfile
  has_one_attached :lesson_content_zipfile

  S3_OBJECT_PREFIX = "lessons".freeze
  INDEX_FILE = "index.html".freeze

  # Publicly accessible URL for the lesson
  def get_index_url
    s3_bucket.object(s3_object_key(INDEX_FILE)).public_url
  end

  # For a file in the zip, returns an S3 object key for a file in the zip
  def s3_object_key(filename)
    [ S3_OBJECT_PREFIX, self.lesson_content_zipfile.key, filename ].join("/")
  end

  # Return S3 bucket
  def s3_bucket
    credentials = Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"])
    Aws.config.update({credentials: credentials})
    s3 = Aws::S3::Resource.new(region: ENV["AWS_REGION"])
    s3.bucket(ENV["AWS_S3_BUCKET"])
  end
end
