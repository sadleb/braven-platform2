class GradeCalculator

  # The total grade for a program is the grade they received for
  # each grade_category adjusted with the relative weights (aka percent_of_grade)
  # that the category is worth towards your overall grade.
  def self.total_grade(user, course)
    raise NotImplementedError
    #course.grade_categories.reduce(0.0) do |final_grade, category| 
    #  final_grade + (category.percent_of_grade * category.grade_for(user)) 
    #end
  end

  # The total grade for a category is the grade for lessons, projects, etc in that 
  # with their relative weight in that category applied. Then adjusted for late submissions
  # or other special rules / policies.

  # Note: points for a given lesson, project, etc are completely independant of the calculation
  # of the total grade for the category. Points just let you more intuitively break down a given
  # project into the number of factors that go into the grade. E.g. if there are 20 questions,
  # it may be intuitive to make the lesson worth 200 points, 10 points per question.
  def self.grade_for_category(user, grade_category)
    raise NotImplementedError
    #TODO: this logic has points interrelated. Write specs that use percent and rewrite this
    #points_received = 0.0
    #points_possible = 0

    #ProjectSubmission.for_projects_and_user(course_module.projects, user).each { |ps| 
    #  points_received += ps.points_received 
    #  points_possible += ps.project.points_possible
    #}

    #LessonSubmission.for_lessons_and_user(course_module.lessons, user).each { |ls| 
    #  points_received += ls.points_received 
    #  points_possible += ls.lesson.points_possible
    #}

    #points_received / points_possible
 
  end
end
