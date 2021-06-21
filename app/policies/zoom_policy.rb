class ZoomPolicy < ApplicationPolicy

  def init_generate_zoom_links?
    index?
  end

  def generate_zoom_links?
    create?
  end

end
