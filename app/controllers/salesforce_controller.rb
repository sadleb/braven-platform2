require 'sync_to_lms'

class SalesforceController < ApplicationController

  def sync_to_lms
    # TODO: prevent anyone with the URL from executing this. Need some sort of auth for SF to be able to call into this.

    # TODO: if this fails, how to report back to the user that forced it from Salesforce?
    # Say it takes a minute or two to run, can we have Salesforce wait for the response?
    # If not, queue this up on the background and have a page listing recent runs and their status?
    # Send an email?
    SyncToLMS.execute(params[:course_id])
  end

end
