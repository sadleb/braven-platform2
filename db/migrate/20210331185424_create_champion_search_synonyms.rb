class CreateChampionSearchSynonyms < ActiveRecord::Migration[6.1]
  def change
    create_table :champion_search_synonyms do |t|
      t.string :search_term, null: false
      t.string :search_becomes, null: false

      t.timestamps

      t.index :search_term
    end
  end
end
