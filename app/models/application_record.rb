class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # See: https://github.com/rails/rails/issues/3508
  # This serializes the `type` column used for single-table inheritance.
  def serializable_hash(options = nil)
    return super(options) unless has_attribute?(self.class.inheritance_column)

    options = options.try(:dup) || {}

    options[:methods]  = Array(options[:methods]).map(&:to_s)
    options[:methods] |= Array(self.class.inheritance_column)

    super(options)
  end
end
