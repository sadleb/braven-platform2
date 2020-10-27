class RemoveContentTypeFromCustomContents < ActiveRecord::Migration[6.0]
  def change
    remove_column :custom_contents, :content_type, :string
  end
end
