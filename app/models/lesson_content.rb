require 'lesson_content_publisher'

# Represents the contents of a Canvas module, e.g. a Rise 360 course
class LessonContent < ApplicationRecord
  # Rise 360 lesson zipfile
  has_one_attached :lesson_content_zipfile

  def launch_url
    # TODO: in a future iteration we'll want to generate pre-signed URLs with expirations on
    # them so that our content doesn't get leaked for anyone to access. Right now the bucket is public
    # but we'll want to lock it down.
    LessonContentPublisher.launch_url(lesson_content_zipfile.key)
  end
    
  def publish
    LessonContentPublisher.publish(lesson_content_zipfile)
  end

end
