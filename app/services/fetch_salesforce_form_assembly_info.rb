# frozen_string_literal: true
require 'salesforce_api'

# Responsible for fetching information about the various Form Assembly forms,
# like Waivers, Pre/Post Accelerator Surveys, to show to a Fellow
class FetchSalesforceFormAssemblyInfo
  attr_reader :program_id, :waivers_form_id, :participant_id,
              :pre_accelerator_survey_form_id, :post_accelerator_survey_form_id

  def initialize(canvas_course_id, user)
    @canvas_course_id = canvas_course_id
    @user = user
  end

  def run
    form_assembly_info = sf_client.get_fellow_form_assembly_info(@canvas_course_id)
    @program_id = form_assembly_info['Id']
    @waivers_form_id = form_assembly_info['FA_ID_Fellow_Waivers__c']
    @pre_accelerator_survey_form_id = form_assembly_info['FA_ID_Fellow_PreSurvey__c']
    @post_accelerator_survey_form_id = form_assembly_info['FA_ID_Fellow_PostSurvey__c']

    @participant_id = sf_client.get_participant_id(@program_id, @user.salesforce_id)

    self 
  end

private

  def sf_client
    SalesforceAPI.client
  end

end
