# Load the Rails application.
require_relative "application"

# Load custom Rails extensions
require 'core_ext/postgresql_adapter'
require 'core_ext/string'
require 'core_ext/activemodel_type_symbol.rb'

# Initialize the Rails application.
Rails.application.initialize!
