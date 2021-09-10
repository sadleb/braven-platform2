class AddMoreIndicesToRise360ModuleInteractions < ActiveRecord::Migration[6.1]
  def change

    # Get rid of our multi column indexes. They are hard to maintain
    # and we didn't benchmark them. Instead of trying to refactor them
    # to work with the new queries in this PR we're going to keep it simple.
    # We'll add multi-column or more finely tuned ones if/when we notice slow
    # queries in prod.
    # Good article: https://devcenter.heroku.com/articles/postgresql-indexes
    # Postgres guidance on multi column ones, column order matters btw: https://www.postgresql.org/docs/12/indexes-multicolumn.html

    add_index :rise360_module_interactions, :canvas_course_id
    add_index :rise360_module_interactions, :verb
    # Note: we alreade have one on canvas_assignment_id and user_id

    # Partial indexes for things we query for and the rows matching the where clause is small
    add_index :rise360_module_interactions, :new, where: "new = true",
      name: "index_rise360_module_interactions_on_new_true"
    add_index :rise360_module_interactions, :progress, where: "progress = 100",
      name: "index_rise360_module_interactions_on_progress_100_percent"

    # Remove the unbenchmarked multi-column ones.
    remove_index :rise360_module_interactions,
      column: ["canvas_assignment_id", "user_id", "verb"],
      name: "index_rise360_module_interactions_on_assignment_user_verb"
    remove_index :rise360_module_interactions,
      column: ["canvas_course_id", "canvas_assignment_id"],
      name: "index_rise360_module_interactions_on_course_assignment"
    remove_index :rise360_module_interactions,
      column: ["new", "canvas_course_id", "canvas_assignment_id", "user_id"],
      name: "index_rise360_module_interactions_on_new_course_assignment_user"
  end
end
