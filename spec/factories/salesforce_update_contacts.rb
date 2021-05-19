FactoryBot.define do

  # Represents a JSON object sent from Salesforce to the SalesforceController#update_contacts
  # endpoint. This object is created from this code: https://github.com/beyond-z/salesforce/blob/master/src/classes/BZ_SyncContactsToCanvas.apxc

  factory :salesforce_update_contacts, class: Hash do
    skip_create # This isn't stored in the DB.
    sequence(:staff_email) { |i| "testsfcontactemail#{i}@sfexample.com" }
    contacts { [] }

    factory :salesforce_update_registered_contact, class: Hash do
      transient do
        fellow_user { build :fellow_user } # This just provides a convenient way to build one of these from a User
        new_email { nil }
      end
      contacts {
        [
          build(:salesforce_contact_in_portal,
            :Email => (new_email || fellow_user.email),
            :ContactId => fellow_user.salesforce_id,
            :FirstName => fellow_user.first_name,
            :LastName => fellow_user.last_name,
            :CanvasUserId => fellow_user.canvas_user_id,
            :LastModifiedDate => '2021-05-19T14:00:19.000Z'
          )
        ]
      }
    end

    initialize_with { attributes.stringify_keys }
  end

end

# Example
#{
#    "staff_email": "the_staff_email@bebraven.org",
#    "contacts": [
#        {
#            "ContactId": "00311555555555TOhAAM",
#            "CanvasUserId": 4321,
#            "Email": "brian+testhighndrdevdevsandboxfellow2_6@bebraven.org",
#            "FirstName": "Brian",
#            "LastModifiedDate": "2021-04-15T12:43:04.000Z",
#            "LastName": "xTestHighndrdevDevSandboxFellow2",
#        }
#    ]
#}
