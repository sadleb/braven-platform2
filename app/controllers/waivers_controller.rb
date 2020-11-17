# frozen_string_literal: true

# Handles launching and submitting waivers that we require folks to sign in order to participate
# in the course.
#
# The waivers form is created in FormAssembly. Here is one example: https://braven.tfaforms.net/forms/builder/5.0.0/4810809
# We configure the a Post Redirect connector on form submission and point it at https://platform.bebraven.org/waivers
# In the Connetor, we configure the fields to be send to the above endpoint with the canvas_user_id and canvas_course_id
# that the waiver is being signed for.
#
# Note: the FormAssembly e-Signature functionality requires access to cookies/local storage.
# This doesn't work in Chrome incognito (and probably Firefox) b/c they disable third party cookies
# by default. To get around this, we start with a launch view where you click a link to bring you
# to the platform app instead of being inside an iFrame in Canvas. We serve the FormAssembly 
# form from our domain using their Rest API: https://help.formassembly.com/help/340360-use-a-server-side-script-api
# so that everything works.
class WaiversController < ApplicationController
  include LtiHelper

  before_action :set_lti_launch, only: [:launch]
  before_action :set_base_course, only: [:publish, :unpublish, :launch]

  WAIVERS_ASSIGNMENT_NAME = 'Complete Waivers'

  # Presents a page to launch the Waivers form in its own window (aka this window) instead of inside an iFrame where
  # the Waivers assignment is shown in Canvas.
  #
  # Note: ideally this would be nested under base_course similar to the rest of the routes, but it
  # means that we'd need to adjust the LtiLaunch URLs when we launch a new Program and the course id changes.
  # This way, it's just a static endpoint for any course to launch the waivers for that course pulling the
  # course info out of the LtiLaunch context.
  #
  # GET /waivers/launch
  def launch
    authorize :waivers
  end

  # POST /course_management/:id/waivers/publish
  def publish
    authorize :waivers

    canvas_assignment = CanvasAPI.client.create_lti_assignment(
      @base_course.canvas_course_id,
      WAIVERS_ASSIGNMENT_NAME,
      Rails.application.routes.url_helpers.launch_waivers_url(protocol: 'https')
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

private

  def set_base_course
    if @lti_launch
      @base_course = BaseCourse.find_by_canvas_course_id!(@lti_launch.request_message.canvas_course_id)
    else
      @base_course = BaseCourse.find(params[:base_course_id])
    end
  end
end
