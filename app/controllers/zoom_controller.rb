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

    # There are two possible encodings for .csv files (well 3 if you count the Windows one).
    # The following encoding appears to work for both Mac versions. I empirically tested this
    # by using Save As: "CSV UTF-8" as well as the plain "CSV" formats with Excel v16.49 on a Mac
    # This article helped me find the fix:
    # https://jamescrisp.org/2020/05/05/importing-excel-365-csvs-with-ruby-on-osx/
    #
    # Also, the "strip_converter" handles stripping/trimming whitespace since it's common for folks
    # to copy/paste a value and end up with a trailing space.
    strip_converter = ->(field) { field.strip }
    participants = CSV.read(params[:participants].path,
                         headers: true,
                         encoding:'bom|utf-8',
                         converters: strip_converter)
                   .map(&:to_h)

    GenerateZoomLinksJob.perform_later(params[:meeting_id], params[:email], participants)

    redirect_to root_path, notice: 'The generation process was started. Watch out for an email'
  end

end
