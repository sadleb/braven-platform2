class AddQuizBreakdownToRise360ModuleAndModuleVersion < ActiveRecord::Migration[6.1]
  def up
    add_column :rise360_modules, :quiz_breakdown, :string
    add_column :rise360_module_versions, :quiz_breakdown, :string

    Rise360Module.all.each do |m|
      Rise360Util.update_metadata!(m)
      m.reload
      m.versions.update_all(quiz_breakdown: m.quiz_breakdown)
    end
  end

  def down
    remove_column :rise360_modules, :quiz_breakdown, :string
    remove_column :rise360_module_versions, :quiz_breakdown, :string
  end
end
