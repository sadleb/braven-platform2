require 'rise360_util'

class Rise360ModuleVersion < ApplicationRecord
  belongs_to :rise360_module
  belongs_to :user

  has_one_attached :rise360_zipfile
  validates :name, presence: true

  def launch_url
   "#{LtiRise360Proxy.proxy_url}#{Rise360Util.launch_path(rise360_zipfile.key)}"
  end
end
