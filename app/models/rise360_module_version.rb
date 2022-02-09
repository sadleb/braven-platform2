require 'rise360_util'

class Rise360ModuleVersion < ApplicationRecord
  # Versions are immutable after they're created. You can delete, though.
  before_update { raise ActiveRecord::ReadOnlyRecord }

  belongs_to :rise360_module
  belongs_to :user

  has_one_attached :rise360_zipfile

  has_many :course_rise360_module_versions
  has_many :courses, -> { distinct }, through: :course_rise360_module_versions

  validates :name, presence: true
  validates :quiz_questions, presence: true
  validates :activity_id, presence: true

  serialize :quiz_breakdown, Array

  # Because the Version is immutable, we only need this callback on create.
  after_create_commit :publish

  def launch_url
   "#{LtiRise360Proxy.proxy_url}#{Rise360Util.launch_path(rise360_zipfile.key)}"
  end

  def self.find_by_lti_launch_url(url)
    rise360_module_version_id = url[/.*\/rise360_module_versions\/(\d+)/, 1]
    return Rise360ModuleVersion.find_by(id: rise360_module_version_id)
  end

private
  def publish
    # Unlike Rise360Module, we don't run update_metadata! to compute
    # quiz_questions and activity_id. Those must be set using the values on the
    # Rise360Module the Version is created from.
    # See Rise360Module::new_version().
    Rise360Util.publish(rise360_zipfile) if rise360_zipfile.attached?
  end
end
