module BaseCoursesHelper

  def humanized_type(base_course)
    case base_course.type
    when 'Course'
      'Course'
    when 'CourseTemplate'
      'Course Template'
    end
  end

  def has_waivers?
    !!@canvas_assignment_info.canvas_waivers_url
  end

  def canvas_waivers_url
    @canvas_assignment_info.canvas_waivers_url
  end

  def canvas_waivers_assignment_id
    @canvas_assignment_info.canvas_waivers_assignment_id
  end

end
