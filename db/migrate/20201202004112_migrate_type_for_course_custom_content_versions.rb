class MigrateTypeForCourseCustomContentVersions < ActiveRecord::Migration[6.0]
  def up
    CourseCustomContentVersion.where(:type => 'BaseCourseProjectVersion').update_all(:type => 'CourseProjectVersion')
    CourseCustomContentVersion.where(:type => 'BaseCourseSurveyVersion').update_all(:type => 'CourseSurveyVersion')
  end

  def down
    # When rolling back, do the opposite of above.
    CourseCustomContentVersion.where(:type => 'CourseProjectVersion').update_all(:type => 'BaseCourseProjectVersion')
    CourseCustomContentVersion.where(:type => 'CourseSurveyVersion').update_all(:type => 'BaseCourseSurveyVersion')
  end
end
