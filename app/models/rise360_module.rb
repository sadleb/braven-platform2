require 'rise360_util'

# Represents the contents of a Canvas module, e.g. a Rise 360 course
class Rise360Module < ApplicationRecord
  include Versionable

  # Note: Callbacks are executed in reverse order.
  after_create_commit :update_metadata!, :publish

  has_one_attached :rise360_zipfile

  validates :name, presence: true

  has_many :rise360_module_versions
  alias_attribute :versions, :rise360_module_versions

  def launch_url
   "#{LtiRise360Proxy.proxy_url}#{Rise360Util.launch_path(rise360_zipfile.key)}"
  end

  # For Versionable
  def new_version(user)
    version = Rise360ModuleVersion.new(
      rise360_module: self,
      user: user,
      name: name,
    )
    version.rise360_zipfile.attach(rise360_zipfile.blob) if rise360_zipfile.attached?
    version
  end

private

  def publish
    # TODO: Extract this asynchronously, and ensure update_metadata runs *after*.
    # https://app.asana.com/0/1174274412967132/1184800386160057
    Rise360Util.publish(rise360_zipfile) if rise360_zipfile.attached?
  end

  def update_metadata!
    Rise360Util.update_metadata!(self) if rise360_zipfile.attached?
  end

end
