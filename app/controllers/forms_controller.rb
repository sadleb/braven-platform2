# frozen_string_literal: true

require 'lti_advantage_api'
require 'canvas_api'

# Handles publishing and unpublishing Forms that Fellows need to sign
# in order to participate in the course.
#
# The 'forms' forms are created in FormAssembly. Here is one example: https://braven.tfaforms.net/forms/builder/5.0.0/4810809
# We configure the a Post Redirect connector on form submission and point it at https://platform.bebraven.org/form_submissions
# In the Connetor.
#
# Note: the FormAssembly e-Signature functionality requires access to cookies/local storage.
# This doesn't work in Chrome incognito (and probably Firefox) b/c they disable third party cookies
# by default. To get around this, we start with a launch view where you click a link to bring you
# to the platform app instead of being inside an iFrame in Canvas. We serve the FormAssembly
# form from our domain using their Rest API: https://help.formassembly.com/help/340360-use-a-server-side-script-api
# so that everything works.
#
# After publishing the forms. The actual launch and submission are handled by FormSubmissionsController
class FormsController < ApplicationController
  include DryCrud::Controllers::Nestable

  # Adds the #publish and #unpublish actions
  include Publishable

  layout 'admin'

  nested_resource_of Course

  # Note: this is the actual name of the assignment. The convention
  # for assignment naming is things like: CLASS: Learning Lab2,
  # MODULE: Lead Authentically, TODO: Complete Forms
  FORMS_ASSIGNMENT_NAME = 'TODO: Complete Forms'

  FORMS_POINTS_POSSIBLE = 10.0

  def assignment_name
    FORMS_ASSIGNMENT_NAME
  end

  def points_possible
    FORMS_POINTS_POSSIBLE
  end

  def lti_launch_url
    launch_form_submissions_url(protocol: 'https')
  end

end
