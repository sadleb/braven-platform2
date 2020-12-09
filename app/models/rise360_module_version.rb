class Rise360ModuleVersion < ApplicationRecord
  belongs_to :rise360_module
  belongs_to :user

  has_one_attached :rise360_zipfile
  validates :name, presence: true
end
