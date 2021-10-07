class MigrateCanSendNewSignupEmailRole < ActiveRecord::Migration[6.1]
  def up
    Role.find_by_name('CanSendNewSignUpEmail')&.update(name: 'CanSendAccountCreationEmails')
  end

  def down
    Role.find_by_name('CanSendAccountCreationEmails')&.update(name: 'CanSendNewSignUpEmail')
  end
end
