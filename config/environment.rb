# Load the Rails application.
require_relative "application"

# Load custom Rails extensions
require 'core_ext/postgresql_adapter'
require 'core_ext/string'
require 'core_ext/activemodel_type_symbol.rb'

# Initialize the Rails application.
Rails.application.initialize!

# Patches that need to be applied after rails is fully initialized.
# Normally you can just drop the patch file in the config/initializers
# but if it has a complex dependency tree and needs to be loaded
# after other normal auto-loaded gems are, here is where you can do that.
require 'cas_sessions_controller_10_4_patch'
