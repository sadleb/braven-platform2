class RenameSearchStatsToChampionStats < ActiveRecord::Migration[6.1]
  def change
    rename_table :search_stats, :champion_stats
  end
end
