# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')
Rails.application.config.assets.paths << Rails.root.join('app', 'assets', 'fonts')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w( layouts/application.css )
Rails.application.config.assets.precompile += %w( layouts/accounts.css )
Rails.application.config.assets.precompile += %w( layouts/admin.css )
Rails.application.config.assets.precompile += %w( layouts/content_editor.css )
Rails.application.config.assets.precompile += %w( layouts/lti_canvas.css )
Rails.application.config.assets.precompile += %w( layouts/form_assembly.css )
Rails.application.config.assets.precompile += %w( layouts/rise360_container.css )
Rails.application.config.assets.precompile += %w( rise360_content.css )
Rails.application.config.assets.precompile += %w( braven_network.css )
Rails.application.config.assets.precompile += %w( test_users.css )

# Add fonts to precompile
Rails.application.config.assets.precompile << /\.(?:svg|eot|woff|ttf)\z/

