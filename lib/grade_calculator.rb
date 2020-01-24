class GradeCalculator

  # The total grade for a program is the grade they received for
  # each course_module adjusted with the relative weights (aka percent_of_grade)
  # that the module is worth towards your overall grade.
  def self.total_grade(user, program)
    program.course_modules.reduce(0.0) do |final_grade, mod| 
      final_grade + (mod.percent_of_grade * mod.grade_for(user)) 
    end
  end

  # The total grade for a module is the sum of all the points they received for
  # every submission in the module out of the total points possible for all 
  # projects, lesssons, etc in it -- applying any adjustment for late submissions
  # or other special rules / policies.
  def self.grade_for_module(user, course_module)
    points_received = 0.0
    points_possible = 0

    ProjectSubmission.for_projects_and_user(course_module.projects, user).each { |ps| 
      points_received += ps.points_received 
      points_possible += ps.project.points_possible
    }

    LessonSubmission.for_lessons_and_user(course_module.lessons, user).each { |ls| 
      points_received += ls.points_received 
      points_possible += ls.lesson.points_possible
    }

    points_received / points_possible
 
  end
end
