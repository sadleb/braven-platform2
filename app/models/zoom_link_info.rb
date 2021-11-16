require 'salesforce_api'

# This represents the information about a Zoom link that we create for a Participant.
# The purpose is to be able to make decisions on whether to generate, update, or cancel a link.
#
# Note that this doesn't actually store the link itself b/c Salesforce is the source of truth
# and we need to make sure to use, create, or update the link there.
class ZoomLinkInfo < ApplicationRecord
  validates :salesforce_participant_id, :salesforce_meeting_id_attribute, :meeting_id,
    :first_name, :last_name, :email, :registrant_id, presence: true

  validates :salesforce_participant_id, length: {is: 18}, allow_blank: false

  validates :salesforce_meeting_id_attribute, inclusion: { in: ['zoom_meeting_id_1', 'zoom_meeting_id_2'],
    message: "%{value} is not a valid salesforce_meeting_id_attribute" }

  # NOTE: about salesforce_participant_id - it may be tempting to use an email to look up this
  # value here, but don't. You should use SalesforceAPI#find_participant() to get the id.
  # If you do need to grab it locally (e.g. for performance reasons) then create a proper
  # Participant model and deal with keeping it in sync with Salesforce (and change this to
  # reference that).


  # Parses a SalesforceAPI::SFParticipant struct into a new ZoomLinkInfo model.
  #   @param [SalesforceAPI::SFParticipant] salesforce_paticipant_struct
  #   @param [symbol] salesforce_meeting_id_attribute: either :zoom_meeting_id_1 or :zoom_meeting_id_2
  #
  # Note: this will fail to save to the database unless you set a registrant_id
  # on it gotten by calling into the ZoomAPI to register them for a meeting.
  def self.parse(salesforce_paticipant_struct, salesforce_meeting_id_attribute)

    # Make it easier to debug and be extra defensive if values other than the two meeting_id
    # attributes we're allowing to be dynamically sent to the struct are used.
    unless [:zoom_meeting_id_1, :zoom_meeting_id_2].include?(salesforce_meeting_id_attribute)
      raise ArgumentError.new("salesforce_meeting_id_attribute=#{salesforce_meeting_id_attribute} not supported")
    end

    ZoomLinkInfo.new(
      salesforce_meeting_id_attribute: salesforce_meeting_id_attribute,
      salesforce_participant_id: salesforce_paticipant_struct.id,
      meeting_id: salesforce_paticipant_struct.send(salesforce_meeting_id_attribute),
      first_name: salesforce_paticipant_struct.first_name,
      last_name: salesforce_paticipant_struct.last_name,
      email: salesforce_paticipant_struct.email,
      prefix: self.compute_prefix(salesforce_paticipant_struct),
    )
  end

  # We prefix their first names when registering them to help with managing breakout rooms.
  # Regional folks need to be able to easily see which Fellows and LCs are in a Cohort so
  # they can put them together in a breakout room. CPs (College Partners) float around and
  # are manually managed in an-hoc manner. We just need to know that they are a CP.
  def first_name_with_prefix
    first_name_with_prefix = first_name
    first_name_with_prefix = prefix + first_name if prefix.present?
    first_name_with_prefix
  end

  # If this returns false, then the details used to register this Participant
  # for this Zoom meeting have changed and the registration needs to be updated.
  #
  # Note: there is no way to "update" a registration. Instead, you have to call
  # the ZoomAPI#add_registrant() endpoint. If the email or meeting_id have changed,
  # that call will create a new registrant and you need to delete the old one to
  # disable that link. If anything else changes, it will return the same registrant.
  # Basically, it acts like an "update". The join_url will not change in that case
  # unless something core to the meeting itself, like the meeting password, changes.
  def registrant_details_match?(other_zoom_link_info)
    (
      meeting_id == other_zoom_link_info.meeting_id &&
      first_name == other_zoom_link_info.first_name &&
      last_name == other_zoom_link_info.last_name &&
      email == other_zoom_link_info.email &&
      prefix == other_zoom_link_info.prefix
    )
  end

private

  def self.compute_prefix(salesforce_paticipant_struct)
    return 'TA - ' if SalesforceAPI.is_teaching_assistant?(salesforce_paticipant_struct)
    return 'CP - ' if SalesforceAPI.is_coach_partner?(salesforce_paticipant_struct)
    return 'LC - ' if SalesforceAPI.is_lc?(salesforce_paticipant_struct)

    # For all other types (aka Fellows), use Zoom prefix from the Cohort. This is as formula
    # on the Salesforce side that for now just uses FirstName LastInitial (e.g. 'Brian S'),
    # but may eventually be a different format for co-LCs, like 'LCName1 & LCName 2'
    # If no Cohort is assigned, it will just be an empty string since we have no info to help
    # with breakout rooms.
    return "#{salesforce_paticipant_struct.zoom_prefix} - " if salesforce_paticipant_struct.zoom_prefix.present?

    return ''
  end

end
