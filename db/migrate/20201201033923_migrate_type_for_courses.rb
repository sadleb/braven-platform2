class MigrateTypeForCourses < ActiveRecord::Migration[6.0]
  def up

    add_column :courses, :is_launched, :boolean, default: false

    # In the old model a "Course" meant it was launched from a CourseTemplate.
    # Convert them to true and default to false for CourseTemplates
    Course.where(:type => 'Course').update_all(:is_launched => true)

    remove_column :courses, :type
  end

  def down
    add_column :courses, :type, :string

    # When rolling back, do the opposite of above.
    Course.where(:is_launched => false).update_all(:type => 'CourseTemplate')
    Course.where(:is_launched => true).update_all(:type => 'Course')

    change_column_null :courses, :type, false
    remove_column :courses, :is_launched
  end
end
