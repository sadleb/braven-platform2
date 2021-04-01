# frozen_string_literal: true

# The LtiLaunch table stores each new launch of a resource through
# the LTI Extension. After a successful handshake between us and Canvas,
# the launch is akin to an authenticated session. The "state" attribute
# of the launch can be used to access resources and be considered authenticated.
# Therefore, we only want an LtiLaunch to exist for a configured period of
# time afterwhich the user has to perform a new launch to act as the authenticated
# session. This job deletes launches that are older than the configured valid timeperiod.
#
# Plus, this table is hit a lot as users access LTI resources through Canvas, so
# we want queries to be lightning fast. If we need to store any information about a launch
# for a long period of time, for example if we want to know which resources are being
# used the most and how often, we should store that info elsewhere. E.g. have each launch
# send an xAPI statement to the LRS recording an activity about what was launches and by whom.
class CleanupLtiLaunchTableJob < ApplicationJob
  queue_as :low_priority

  def perform
    # The value of 'lti_launch_remember_for' can be a Rails Time helper like 2.weeks or the
    # number of seconds, like 1209600 (this is also 2 weeks)
    cutoff_time = Time.at(Time.now - eval(Rails.application.secrets.lti_launch_remember_for))
    Honeycomb.add_field('lti_launch_cleanup.current_server_time', Time.now)
    Honeycomb.add_field('lti_launch_cleanup.cutoff_time', cutoff_time)

    start_msg = "Cleaning up LtiLaunches older than #{cutoff_time}"
    Rails.logger.info(start_msg)

    # Use updated_at so that continuing to interact with the launch extends it's validity.
    records_to_delete = LtiLaunch.where("updated_at < ?", cutoff_time)
    total_count = LtiLaunch.count
    count = records_to_delete.count
    records_to_delete.delete_all if count > 0

    finish_msg = "#{count} out #{total_count} LtiLaunch records deleted. Done cleaning up old LtiLaunches"
    Rails.logger.info(finish_msg)
    Honeycomb.add_field('lti_launch_cleanup.records_to_delete.count', count)
    Honeycomb.add_field('lti_launch_cleanup.total_records.count', total_count)
  end

end
