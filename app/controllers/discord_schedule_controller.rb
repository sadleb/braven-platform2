# frozen_string_literal: true

require 'discord_bot'

# Schedule Discord messages to send later.
class DiscordScheduleController < ApplicationController
  layout 'admin'

  # Disable putting everything inside a "discord_schedule" param. This controller doesn't represent a model.
  wrap_parameters false

  before_action :set_all_cohort_key

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
      name: DiscordServer.find_by(discord_server_id: id.to_s).name,
      id: id
    } }.sort_by! { |s| s[:name] }
  end

  def create
    authorize :discord_schedule

    params.require([:server_id, :channel_id, :message, :datetime, :timezone])

    service = ScheduleDiscordMessage.new(
      params[:server_id],
      params[:channel_id],
      params[:message],
      params[:datetime],
      params[:timezone]
    )
    service.run

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

private

  # Set an instance variable so we can access this from the views.
  # Treat this variable as if it were a constant.
  def set_all_cohort_key
    @all_cohort_key = COHORT_CHANNEL_PREFIX
  end
end
