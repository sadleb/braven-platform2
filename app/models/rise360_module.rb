require 'rise360_util'

# Represents the contents of a Canvas module, e.g. a Rise 360 course
class Rise360Module < ApplicationRecord
  include Versionable

  after_save :set_rise360_zipfile_changed, if: :saved_change_to_rise360_zipfile?
  after_commit :publish, if: :rise360_zipfile_changed?

  has_one_attached :rise360_zipfile

  validates :name, presence: true

  has_many :rise360_module_versions
  alias_attribute :versions, :rise360_module_versions

  # This flag is used to track changes to the rise360_zipfile, so we don't
  # run expensive callbacks if we've only updated another column (e.g., name).
  # It persists attachment_changes.key([:rise360_zipfile]), which is
  # ActiveModel's way of tracking changes to attachments. In ActiveModel's
  # implementation, attachment_changes is not available in the commit hooks
  # because all of the changes are already persisted to the DB. However,
  # we only have access to the ActiveStorage attachment in the commit state, 
  # hence this custom flag.
  attr_accessor :rise360_zipfile_changed

  after_initialize do |rise360_module|
    rise360_module.rise360_zipfile_changed = false
  end

  def launch_url
   "#{LtiRise360Proxy.proxy_url}#{Rise360Util.launch_path(rise360_zipfile.key)}"
  end

  # For Versionable
  def new_version(user)
    version = Rise360ModuleVersion.new(
      rise360_module: self,
      user: user,
      name: name,
      activity_id: activity_id,
      quiz_questions: quiz_questions,
    )
    version.rise360_zipfile.attach(rise360_zipfile.blob) if rise360_zipfile.attached?
    version
  end

private
  def saved_change_to_rise360_zipfile?
    # ActiveModel::Dirty tracks changes to ActiveStorage attachments differently
    # from other model attributes.
    # See: https://github.com/rails/rails/issues/37412
    attachment_changes.key?(:rise360_zipfile.to_s)
  end

  def rise360_zipfile_changed?
    self.rise360_zipfile_changed
  end

  def set_rise360_zipfile_changed
    self.rise360_zipfile_changed = true
  end

  def publish
    if rise360_zipfile.attached?
      # TODO: Extract this asynchronously
      # https://app.asana.com/0/1174274412967132/1184800386160057
      launch_path = Rise360Util.publish(rise360_zipfile)

      # Note: This must be set **before** we call update_metadata! below.
      # Otherwise, the update! call in update_metadata! will trigger an
      # infinite loops on publish.
      self.rise360_zipfile_changed = false
      Rise360Util.update_metadata!(self)
    else
      self.rise360_zipfile_changed = false
    end
  end
end
