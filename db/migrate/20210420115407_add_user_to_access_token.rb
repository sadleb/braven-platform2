class AddUserToAccessToken < ActiveRecord::Migration[6.1]
  def change
    # All tokens will now need an associated user, so trucate the existing ones
    # and set them up again
    AccessToken.delete_all
    add_reference :access_tokens, :user, foreign_key: true, null: false
  end
end
