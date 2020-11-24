# frozen_string_literal: true

require 'lti_advantage_api'
require 'canvas_api'

# Handles publishing and unpubliching Waivers forms that Fellows need to sign
# in order to participate in the course.
#
# The waivers forms are created in FormAssembly. Here is one example: https://braven.tfaforms.net/forms/builder/5.0.0/4810809
# We configure the a Post Redirect connector on form submission and point it at https://platform.bebraven.org/waiver_submissions
# In the Connetor.
#
# Note: the FormAssembly e-Signature functionality requires access to cookies/local storage.
# This doesn't work in Chrome incognito (and probably Firefox) b/c they disable third party cookies
# by default. To get around this, we start with a launch view where you click a link to bring you
# to the platform app instead of being inside an iFrame in Canvas. We serve the FormAssembly 
# form from our domain using their Rest API: https://help.formassembly.com/help/340360-use-a-server-side-script-api
# so that everything works.
#
# After publishing the waivers. The actual launch and submission are handled by WaiverSubmissionsController
class WaiversController < ApplicationController
  include DryCrud::Controllers::Nestable
  include Rails.application.routes.url_helpers

  layout 'form_assembly'

  nested_resource_of BaseCourse

  # Note: the TODO here is the actual name of the assignment. The convention
  # for assignment naming is things like: CLASS: Learning Lab2,
  # MODULE: Lead Authentically, TODO: Submit Peer Reviews
  WAIVERS_ASSIGNMENT_NAME = 'TODO: Complete Waivers'

  # POST /course_management/:id/waivers/publish
  def publish
    authorize :waivers

    canvas_assignment = CanvasAPI.client.create_lti_assignment(
      @base_course.canvas_course_id,
      WAIVERS_ASSIGNMENT_NAME,
      launch_waiver_submissions_url(protocol: 'https')
    )

    respond_to do |format|
      format.html { redirect_to edit_polymorphic_path(@base_course), notice: 'Waivers assignment successfully published to Canvas.' }
      format.json { head :no_content }
    end
  end

  # POST /course_management/:id/waivers/unpublish
  def unpublish
    authorize :waivers

    CanvasAPI.client.delete_assignment(@base_course.canvas_course_id, params[:canvas_waivers_assignment_id])

    respond_to do |format|
      format.html { redirect_to edit_polymorphic_path(@base_course), notice: 'Waivers assignment successfully deleted from Canvas.' }
      format.json { head :no_content }
    end
  end

end
