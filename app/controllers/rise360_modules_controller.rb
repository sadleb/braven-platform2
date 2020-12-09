# frozen_string_literal: true

class Rise360ModulesController < ApplicationController
  # Add the #new and #create actions
  include Attachable
  include LtiHelper

  layout 'admin'

  before_action :set_lti_launch, only: [:create, :show]
  skip_before_action :verify_authenticity_token, only: [:create, :show], if: :is_sessionless_lti_launch?

  def show
    authorize @rise360_module
    # TODO: this may be while previewing the the Lesson before inserting it through the
    # assignment selection placement. Don't configure it to talk to the LRS in that case.
    # https://app.asana.com/0/search/1189124318759625/1187445581799823
    url = Addressable::URI.parse(@rise360_module.launch_url)
    url.query_values = helpers.launch_query
    redirect_to url.to_s
  end
end
