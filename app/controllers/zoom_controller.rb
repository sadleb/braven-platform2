# frozen_string_literal: true
require 'csv'

class ZoomController < ApplicationController
  layout 'admin'

  # Show a form letting you upload a .CSV file of names and emails to generate unique
  # Zoom links for each meeting participant.
  # GET /generate_zoom_links
  def init_generate_zoom_links
    authorize :Zoom
  end

  # Create the unique Zoom links for folks in the .CSV from #init_generate_zoom_links
  # POST /generate_zoom_links
  def generate_zoom_links
    authorize :Zoom

    generate_service = GenerateZoomLinks.new(
      meeting_id: params[:meeting_id],
      participants_file_path: params[:participants].path,
      email: params[:email]
    )
    csv = generate_service.validate_and_run()
    redirect_to generate_zoom_links_path, notice: 'The generation process was started. Watch out for an email'
  end
end
