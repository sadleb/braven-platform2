# Load the Rails application.
require_relative "application"

# Load custom Rails extensions
require 'core_ext/postgresql_adapter'
require 'core_ext/string'

# Initialize the Rails application.
Rails.application.initialize!
