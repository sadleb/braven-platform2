module CoursesHelper

  def has_waivers?
    !!@canvas_assignment_info.canvas_waivers_url
  end

  def canvas_waivers_url
    @canvas_assignment_info.canvas_waivers_url
  end

  def canvas_waivers_assignment_id
    @canvas_assignment_info.canvas_waivers_assignment_id
  end

  def has_peer_reviews_assignment?
    !!@canvas_assignment_info.canvas_peer_reviews_url
  end

  def canvas_peer_reviews_url
    @canvas_assignment_info.canvas_peer_reviews_url
  end

  def canvas_peer_reviews_assignment_id
    @canvas_assignment_info.canvas_peer_reviews_assignment_id
  end
end
