class DiscordServerChannelsController < ApplicationController

  include DryCrud::Controllers::Nestable
  nested_resource_of DiscordServer

  def index
    authorize DiscordServerChannel
  end

end
