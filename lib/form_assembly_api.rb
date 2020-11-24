require 'rest-client'

# Provides access for FormAssembly forms that can be embedded in this platform app
# server side. See: https://help.formassembly.com/help/340360-use-a-server-side-script-api
class FormAssemblyAPI

  # Use this to get an instance of the API client configured to hit FormAssembly
  # REST API endpoints.
  def self.client
    @client_instance ||= new(Rails.application.secrets.form_assembly_url)
  end

  # Returns the HTML head fragment and HTML body fragment as a tuple (array with 2 items) 
  # given the ID of the FormAssembly form.
  #
  # Optionally, pass any query parameters the form expects at the end.
  #
  # Example Usage:
  # @form_head, @form_body = FormAssemblyAPI.client.get_form_head_and_body(1234567, participantId: a2X1XXXXXXXmQfEUAU)
  def get_form_head_and_body(form_id, query_params = {})
    response = RestClient.get("#{@form_assembly_url}/rest/forms/view/#{form_id}", {params: query_params})
    split_head_and_body(response)
  end

  # Returns the HTML head fragment and HTML body fragment as a tuple (array with 2 items) 
  # given the value of the 'tfa_next' parameter sent by Form Assembly
  #
  # Example Usage:
  # @form_head, @form_body = FormAssemblyAPI.client.get_next_form_head_and_body(params[:tfa_next])
  def get_next_form_head_and_body(tfa_next_param)
    response = RestClient.get("#{@form_assembly_url}/rest/#{tfa_next_param}")
    split_head_and_body(response)
  end
 

private

  def initialize(form_assembly_url)
    @form_assembly_url = form_assembly_url
  end

  def split_head_and_body(response)
    head, body = response.body.split(BODY_DELIMETER)
    head.slice!(HEAD_DELIMETER)
    [head.strip, body.strip]
  end

  # This is weird, but it's how their REST API is meant to be used
  HEAD_DELIMETER = '<!-- FORM: HEAD SECTION -->'
  BODY_DELIMETER = '<!-- FORM: BODY SECTION -->'
end
