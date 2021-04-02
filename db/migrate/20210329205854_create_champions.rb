class CreateChampions < ActiveRecord::Migration[6.1]
  def change
    create_table :champions do |t|
      t.string "first_name", null: false
      t.string "last_name", null: false
      t.string "email", null: false
      t.string "phone", null: false
      t.string "linkedin_url", null: false
      t.string "industries", null: false
      t.string "studies", null: false
      t.string "region"
      t.string "company"
      t.string "job_title"
      t.boolean "braven_fellow"
      t.boolean "braven_lc"
      t.boolean "willing_to_be_contacted"
      t.timestamps

      t.index :email
    end
  end
end
