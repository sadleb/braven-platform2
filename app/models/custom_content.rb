require 'canvas_api'

class CustomContent < ApplicationRecord
  include Versionable

  has_many :custom_content_versions
  alias_attribute :versions, :custom_content_versions

  has_many :course_custom_content_versions, through: :custom_content_versions
  has_many :courses, -> { distinct }, through: :course_custom_content_versions

  scope :projects, -> { where type: 'Project' }
  scope :surveys, -> { where type: 'Survey' }

  # For Versionable
  def new_version(user)
    version_class.new(
      custom_content: self,
      user: user,
      title: title,
      body: body,
    )
  end

private
  def version_class
    "#{self.class.name}Version".safe_constantize
  end
end
