# frozen_string_literal: true
require 'honeycomb-beeline'
require 'logger'

# Standardized methods to instrument Braven's code
#
# The Honeycomb module is extended with this in config/initializer/honeycomb.rb
# so that we can add or override methods for the Honeycomb namespace
module HoneycombBraven

  # TODO: cutover all alerts to use this and update triggers
  # https://app.asana.com/0/1201131148207877/1202052488545511

  # Standardize Honeycomb alerts to make it easier to setup triggers.
  # Instead of needing to maintain a list of all alert field names,
  # we can just setup triggers on a particular class's alerts and
  # further filter them by name, message, level if needed.
  #
  # Example:
  # --------
  # class MyClass
  #
  #   def some_method
  #     Honeycomb.start_span(name: 'some_span') do
  #       Honeycomb.send_alert('something_failed', 'some message about the alert', :alerts_platform, :warn)
  #     end
  #   end
  # end
  #
  # Then running:
  # irb> MyClass.new.some_method()
  #
  # Would result in a span with the following fields:
  # - name:                        'some_span'
  # - app.alert:          'warn'
  # - app.alert_name:     'something_failed'
  # - app.alert_channel:  'alerts_platform'
  # - app.alert_message:  'some message about the alert'
  # - app.alert_class:    'my_class'
  #
  # @param [symbol] channel
  #
  #   :alerts_platform
  #     - Alerts that Product Support should be aware of. Things that are
  #       are not bugs. E.g. bad Salesforce data leading to sync errors, users with
  #       invalid signup links, user's trying to login with the wrong email, etc.
  #
  #
  #   :alerts_eng_highlander
  #     - Alerts that engineers should be aware of. Things that could be bugs
  #       or issues with the site.
  #
  def add_alert(name, message, channel=:alerts_eng_highlander, level=:error)

    # A caller_location is one of these:
    # https://ruby-doc.org/core-3.0.0/Thread/Backtrace/Location.html
    # The first item is the direct file that called this (0 is this file)
    calling_file_path = caller_locations(1,1).first.path
    klass = File.basename(calling_file_path, '.rb')

    Honeycomb.add_field('alert', level)
    Honeycomb.add_field('alert_name', name)
    Honeycomb.add_field('alert_channel', channel)
    Honeycomb.add_field('alert_message', message)
    Honeycomb.add_field('alert_class', klass)

    case level
    when :error
      Rails.logger.error(message)
    when :warn
      Rails.logger.warn(message)
    when :info
      Rails.logger.info(message)
    else
      Rails.logger.debug(message)
    end
  end

  # Convenience method to send alerts that Product Support should be aware of and engineers
  # can generally ignore.
  def add_support_alert(name, message, level=:error)
    Honeycomb.add_alert(name, message, :alerts_platform, level)
  end

end
