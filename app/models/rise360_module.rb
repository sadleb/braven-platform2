require 'rise360_util'

# Represents the contents of a Canvas module, e.g. a Rise 360 course
# NOTE: You probably don't want to use Rise360Module.quiz_questions
# directly! To get the number of quiz questions in a given module, always
# use Rise360ModuleVersion.quiz_questions instead!
class Rise360Module < ApplicationRecord
  include Versionable

  # TODO: this constant is used to convert a score into a percent in the grading
  # code. To make this not be insanely brittle, we should actually use this to set
  # the points_possible when we publish a Module. We should also prevent folks from
  # changing it in the Canvas UI. Currently, we assume Designers properly go set all Modules to
  # be worth 10 points. Grading will BREAK if that doesn't happen.
  # https://app.asana.com/0/1174274412967132/1199231117515061
  POINTS_POSSIBLE=10

  after_save :set_rise360_zipfile_changed, if: :saved_change_to_rise360_zipfile?
  after_commit :publish, if: :rise360_zipfile_changed?
  before_destroy :purge

  has_one_attached :rise360_zipfile

  validates :name, presence: true

  has_many :rise360_module_versions
  alias_attribute :versions, :rise360_module_versions

  serialize :quiz_breakdown, Array

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
      quiz_breakdown: quiz_breakdown,
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

  def purge
    rise360_zipfile.purge if rise360_zipfile.attached?
  end
end
