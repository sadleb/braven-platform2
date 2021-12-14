# Taken from here: https://github.com/wecohere/activemodel_type_symbol/blob/primary/lib/activemodel_type_symbol.rb
#
# Makes the following work so that the MyModel#my_column attribute is returned as a symbol:
# class MyModel < ApplicationRecord
#  attribute :my_column, :symbol
#
require 'active_model/type'

module ActiveModel
  module Type
    class Symbol < ActiveModel::Type::String
      def cast(value)
        return nil if value.nil?
        raise ArgumentError, "#{value} doesn't respond to #to_sym" unless value.respond_to?(:to_sym)
        value.to_sym
      end
    end
  end
end

ActiveModel::Type.register(:symbol, ActiveModel::Type::Symbol)
if Object.const_defined?(:ActiveRecord)
  ActiveRecord::Type.register(:symbol, ActiveModel::Type::Symbol)
end
