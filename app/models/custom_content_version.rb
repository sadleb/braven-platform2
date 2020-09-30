class CustomContentVersion < ApplicationRecord
  belongs_to :course_content
  belongs_to :user
end
