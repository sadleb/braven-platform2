# frozen_string_literal: true

# Schedule Discord messages to send later.
class DiscordScheduleController < ApplicationController
  layout 'admin'

  # Disable putting everything inside a "discord_schedule" param. This controller doesn't represent a model.
  wrap_parameters false

  def index
    authorize :discord_schedule

    # Make a list of hashes describing scheduled Discord jobs,
    # sorted by schedule timestamp, oldest first.
    @jobs = Sidekiq::ScheduledSet.new.map { |j| { at: j.at, info: j.args[0], id: j.jid } }
      .filter { |j| j[:info]['job_class'] == 'SendDiscordMessageJob' }
      .map { |j| {
        at: j[:at],
        server_id: j[:info]['arguments'][0].to_i,
        channel: j[:info]['arguments'][1],
        message: j[:info]['arguments'][2],
        id: j[:id]
      }
    }.sort_by! { |j| j[:at] }

    # From the scheduled jobs, get a list of only the servers that
    # have something scheduled, with both their name and Discord
    # server ID. Sort by name.
    server_ids = @jobs.map { |j| j[:server_id] }.uniq
    @servers = server_ids.map { |id| {
      name: DiscordConstants::NAME_FROM_ID[id],
      id: id
    } }.sort_by! { |s| s[:name] }
  end

  def create
    authorize :discord_schedule

    params.require([:server_id, :channel, :message, :datetime, :timezone])

    run_at = Time.use_zone(params[:timezone]) { Time.zone.parse(params[:datetime]) }
    server_id = params[:server_id].to_i
    # Strip '#'s out of the channel name, bc they're invalid.
    # (Most likely scenario is someone entered the leading # before the channel
    # name, which they're not supposed to do.)
    channel_name = params[:channel]&.delete('#')
    message_content = params[:message]

    # Schedule the job.
    SendDiscordMessageJob.set(wait_until: run_at).perform_later(server_id, channel_name, message_content)

    redirect_to discord_schedule_index_path
  end

  def new
    authorize :discord_schedule
  end

  def destroy
    authorize :discord_schedule

    params.require([:id])

    Sidekiq::ScheduledSet.new.find_job(params[:id]).delete

    redirect_to discord_schedule_index_path
  end
end
