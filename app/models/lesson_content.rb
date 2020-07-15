class LessonContent < ApplicationRecord
  # Uses config/{RAILS_ENV}.rb configuration unless you override it here
  # , service: :local
  # , service: :amazon
  has_one_attached :lesson_content_zipfile

  def path
  	ActiveStorage::Blob.service.send(:path_for, lesson_content_zipfile.key)
  	# rails_blob_path(@lesson_content.lesson_content_zipfile, disposition: "attachment")
  end

  # This is the disk path
  # def lesson_content_zipfile_on_disk
  #   ActiveStorage::Blob.service.send(:path_for, avatar.key)
  # end

end
