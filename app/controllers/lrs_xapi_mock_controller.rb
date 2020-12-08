# frozen_string_literal: true

# Pretend to be an LRS, so Rise 360 content works.
# Most of the code is in the lib below.
require "lrs_xapi_mock"

class LrsXapiMockController < ApplicationController
  skip_before_action :verify_authenticity_token
  wrap_parameters false # Disable putting everything inside a "lrs_xapi_mock" param. This controller doesn't represent a model.

  def xAPI
    authorize :lrs_xapi_mock, :xAPI?

    # If this excepts, we let Rails handle it and return the 500.
    response_hash = LrsXapiMock.handle_request!(request, request.params['endpoint'], current_user)
    if response_hash
      # Note: have to be explicit with the content type here b/c it may "look" like json (and is) sometimes but
      # the Rise360 package PUT/GET's it as plain data and fails if we say it's json. I'm at a loss as to why.
      render plain: response_hash[:body], status: response_hash[:code], content_type: LrsXapiMock::OCTET_STREAM_MIME_TYPE and return
    else
      render plain: 'Not Found', status: 404 and return
    end
  end
end
