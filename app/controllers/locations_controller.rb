class LocationsController < ApplicationController

  # GET /locations
  # GET /locations.json
  def index
    @locations = Location.paginate(page: params[:page])
  end

  # GET /locations/1
  # GET /locations/1.json
  def show
  end

  private
  
end
