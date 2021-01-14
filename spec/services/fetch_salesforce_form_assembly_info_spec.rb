require 'rails_helper'

RSpec.describe FetchSalesforceFormAssemblyInfo do

  let(:participant_id) { 'a2X11000000lakXEAQ' }
  let(:program_id) { 'a2Y1J00000034NKUAY' }
  let(:sf_form_assembly_info) { build :salesforce_fellow_form_assembly_info_record, program_id: program_id }
  let(:canvas_course_id) { 87865645 }
  let(:fellow_user) { create :fellow_user }
  let(:sf_client) { double(SalesforceAPI) }

  before(:each) do
    allow(sf_client).to receive(:get_fellow_form_assembly_info).and_return(sf_form_assembly_info)
    allow(sf_client).to receive(:get_participant_id).and_return(participant_id)
    allow(SalesforceAPI).to receive(:client).and_return(sf_client)
  end

  subject(:form_assembly_info) do
    FetchSalesforceFormAssemblyInfo.new(canvas_course_id, fellow_user).run
  end

  context 'for valid course and user' do

    it 'gets the Fellow Waivers ID' do
      expect(form_assembly_info.waivers_form_id).to eq(sf_form_assembly_info['FA_ID_Fellow_Waivers__c'])
    end

    it 'gets the Pre-Accelerator ID' do
      expect(form_assembly_info.pre_accelerator_survey_form_id).to eq(sf_form_assembly_info['FA_ID_Fellow_PreSurvey__c'])
    end

    it 'gets the Post-Accelerator ID' do
      expect(form_assembly_info.post_accelerator_survey_form_id).to eq(sf_form_assembly_info['FA_ID_Fellow_PostSurvey__c'])
    end

    it 'gets the Program ID' do
      expect(form_assembly_info.program_id).to eq(program_id)
    end

    it 'gets the Participant ID' do
      expect(form_assembly_info.participant_id).to eq(participant_id)
    end
  end

  context 'for invalid Participant' do
     let(:participant_id) { '' }

     it 'raises an exception' do
       expect { form_assembly_info }.to raise_error(FetchSalesforceFormAssemblyInfo::FetchSalesforceFormAssemblyInfoError)
     end
  end

end
