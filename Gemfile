# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '~> 3.1.2'
gem 'rails', '~> 7.0.0'

# https://stackoverflow.com/questions/71191685/visit-psych-nodes-alias-unknown-alias-default-psychbadalias
gem 'psych', '< 4'

gem 'pg'

# Use Puma as the app server
gem 'puma', '~> 5.6'

# Use SCSS for stylesheets
# TODO: migrate to cssbundling
# See here for writeup: https://dev.to/kolide/how-to-migrate-a-rails-6-app-from-sass-rails-to-cssbundling-rails-4l41
gem 'sass-rails', '~> 5'

#TODO: see if webpacker can be upgraded. Had issues before
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem 'webpacker', '~> 4.0'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]

  gem 'dotenv'
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'shoulda-matchers'
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'listen', '>= 3.3.0'
  gem 'web-console', '>= 3.3.0'

  # Require rack-livereload in development bc we use it in config/environments/development.rb.
  gem 'rack-livereload', require: true

  gem 'guard-livereload', require: false
  gem 'guard-rails', require: false
  gem 'guard-rspec', require: false
  gem 'guard-webpacker', require: false
  gem 'guard-yarn', require: false
  gem 'libnotify', require: false
  gem 'pry-rescue', require: false
  gem 'pry-stack_explorer', require: false
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false

  #TODO: see if I can upgrade this gem
  gem 'webpacker-react', '~> 1.0.0.beta.1'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  # Note that v3 doesn't support Ruby 3 that well. See: https://github.com/SeleniumHQ/selenium/issues/9001
  gem 'selenium-webdriver', '>= 4.2.0'
  # Easy installation and use of web drivers to run system tests with browsers
  gem 'webdrivers'
  # HTTP request mocking
  gem 'webmock', require: false

  # Report test coverage
  gem 'simplecov', require: false
  gem 'simplecov-cobertura', require: false

  # Clean database after tests
  gem 'database_cleaner', require: false

  # Stores mocks in reusable file
  gem 'vcr'

  # Allows accessing instance variables passed to your views
  gem 'rails-controller-testing'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

gem 'bulk_insert'
gem 'paranoia'
gem 'will_paginate'

gem 'rest-client'

gem 'devise'
# Pin to v1x since v2x is a complete rewrite of the gem that would take a lot
# of work to upgrade. See cas_sessions_controller_10_4_patch.rb for code that
# patches this to work with Rails 7 while not upgrading the gem to 2x.
# Also see the devise_cas_authenticable_2_0 branch for where I started to try the upgrade
# TODO: upgrade to devise_cas_authenticatable 2.0.
gem 'devise_cas_authenticatable', '~> 1'

gem 'react-rails'

gem 'sentry-ruby'
gem 'sentry-rails'
gem 'sentry-sidekiq'

# Using a branch for a time being to remove R18n until we decide what we want to do
gem 'rubycas-server-activerecord'
gem 'rubycas-server-core', github: 'bebraven/rubycas-server-core', branch: 'platform-compat'

# Honeycomb
gem 'honeycomb-beeline'
gem 'libhoney'

# Allows us to write rake tasks that can programatticaly run Heroku commands
# using their API. E.g. create a task to restart a dyno so it can be run
# in the middle of the night to avoid downtime when users are on the platform
# See: https://github.com/heroku/platform-api
gem 'platform-api', require: false

# Implementation of JSON Web Token (JWT) standard: https://github.com/jwt/ruby-jwt
gem 'jwt'

gem 'aws-sdk-s3'
gem 'rubyzip'
gem 'rexml'

gem 'rails_same_site_cookie'

# authorization
gem "pundit"
gem "rolify"

gem "discordrb", git: 'https://github.com/shardlab/discordrb', branch: 'main', require: false

# Provides better configuration for auto-scaling dynos on Heroku
# than the out of the box options. See:
# See: https://elements.heroku.com/addons/rails-autoscale
gem 'rails_autoscale_agent'  # NOTE: don't use require false. It doesn't work to load in initializer for some reason.

gem 'sidekiq', require: false
gem 'sidekiq-scheduler', require: false
gem 'sidekiq-unique-jobs', require: false
