require 'canvas_api'

class CustomContent < ApplicationRecord
  has_many :custom_content_versions
  alias_attribute :versions, :custom_content_versions

  scope :projects, -> { where type: 'Project' }
  scope :surveys, -> { where type: 'Survey' }

  def courses
    custom_content_versions.map { |v| v.courses or [] }.reduce(:+) or []
  end

  def courses
    custom_content_versions.map { |v| v.courses }.reduce(:+) or []
  end

  def last_version
    return nil unless custom_content_versions.exists?
    custom_content_versions.last
  end

  def save_version!(user)
    published_at = DateTime.now
    new_version = CustomContentVersion.new({
        custom_content_id: id,
        title: title,
        body: body,
        user: user,
        type: set_version_type,
      })

    transaction do
      new_version.save!
      save!
    end
    new_version
  end

  private

  def set_version_type
    case type
    when 'Project'
      'ProjectVersion'
    when 'Survey'
      'SurveyVersion'
    end
  end
end
