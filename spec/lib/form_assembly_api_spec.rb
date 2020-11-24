require 'rails_helper'
require 'form_assembly_api'

RSpec.describe FormAssemblyAPI do

  let(:participant_id) { 'a2X11000000lakXEAQ' }
  let(:form_id) { 129876 }
  let(:tfa_next_path) { 'some/path/to/endpoint/for/next/form' }
  let(:form_assembly_url) { Rails.application.secrets.form_assembly_url }

  # See: https://help.formassembly.com/help/340358-embed-your-forms-html#embed-the-code-within-your-site
  let(:form_assembly_form) {
<<-EOFHTML
<!-- FORM: HEAD SECTION -->
<headcontent>
<!-- FORM: BODY SECTION -->
<bodycontent>
EOFHTML
   }

  describe '#get_form_head_and_body' do

    it 'hits the FormAssemblyAPI correctly' do
      initial_form_api_url = "#{form_assembly_url}/rest/forms/view/#{form_id}?participantId=#{participant_id}"
      stub_request(:any, initial_form_api_url).to_return( body: form_assembly_form )

      form_head, form_body = FormAssemblyAPI.client.get_form_head_and_body(form_id, participantId: participant_id )

      expect(WebMock).to have_requested(:get, initial_form_api_url).once
      expect(form_head).to eq('<headcontent>')
      expect(form_body).to eq('<bodycontent>')
    end
  end

  describe '#get_nextform_head_and_body' do

    it 'hits the FormAssemblyAPI correctly' do
      next_form_api_url = "#{form_assembly_url}/rest/#{tfa_next_path}"
      stub_request(:any, next_form_api_url).to_return( body: form_assembly_form )

      form_head, form_body = FormAssemblyAPI.client.get_next_form_head_and_body(tfa_next_path)

      expect(WebMock).to have_requested(:get, next_form_api_url).once
      expect(form_head).to eq('<headcontent>')
      expect(form_body).to eq('<bodycontent>')
    end
  end

end
