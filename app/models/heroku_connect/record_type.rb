# frozen_string_literal: true

class HerokuConnect::RecordType < HerokuConnect::HerokuConnectRecord
  self.table_name = 'recordtype'

  # type cast these from strings to symbols to make the code cleaner
  # Note: use the SalesforceConstants::RoleCategory.FOO to check against
  # the possible values for this
  attribute :name, :symbol

  has_many :candidates, foreign_key: 'recordtypeid'
  has_many :participants, foreign_key: 'recordtypeid'
  has_many :programs, foreign_key: 'recordtypeid'

  # IMPORTANT: Add columns you want to select by default here. If a new
  # Salesforce field is mapped in Heroku Connect that you want to use,
  # it must be added to this list.
  #
  # See HerokuConnect::HerokuConnectRecord for more info
  def self.default_columns
    [
      :id, :sfid, :createddate,
      :name,
    ]
  end

end
