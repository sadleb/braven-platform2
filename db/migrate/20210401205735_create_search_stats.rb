class CreateSearchStats < ActiveRecord::Migration[6.1]
  def change
    create_table :search_stats do |t|
      t.string :search_term, null: false
      t.integer :search_count, default: 0

      t.timestamps
    end
  end
end
