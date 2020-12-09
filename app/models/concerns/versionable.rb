# frozen_string_literal: true
# 
# "Versionable" behavior for models like
#   - CustomContent
#   - Rise360Module
# 
# This concern handles the following for your model:
#   - last_version: return the last version (if any) for your content
#   - create_version!: save a new version with the current content data
#
# Usage:
#
# class MyModel
#   include Versionsable
#   def new_version(user)
#   end
#
# When using this concern, you must also have a model representing the version:
# class MyModelVersion

module Versionable
  extend ActiveSupport::Concern

  def last_version
    return nil unless versions.exists?
    versions.last
  end

  def create_version!(user)
    version = new_version(user)
    transaction do
      version.save!
      save!
    end
    version
  end

private
  def method_missing(name, *args, &block)
    raise NoMethodError, method_missing_error_msg(name) if name == :new_version
    super
  end

  def method_missing_error_msg(name)
    "Versionable expects method `#{name}` to be defined for #{self.class}."
  end
end
