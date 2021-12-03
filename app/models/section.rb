require 'canvas_api'

class Section < ApplicationRecord
  resourcify

  belongs_to :course

  before_validation { name.try(:strip!) }
  before_destroy :delete_canvas_section

  # All users, with any role, in this section.
  # This is a function just because I don't know how to write it as an association.
  def users
    all_users = []
    roles.distinct.map { |r| r.name }.each do |role_name|
      all_users += User.with_role(role_name, self)
    end
    all_users.uniq
  end

  # More efficient query if you want a specific role:
  def users_with_role(role_name)
    User.with_role(role_name, self)
  end

  def students
    users_with_role(RoleConstants::STUDENT_ENROLLMENT)
  end

private

  # Raises RestClient::BadRequest if the Canvas section has enrollments.
  def delete_canvas_section
    CanvasAPI.client.delete_section(canvas_section_id) unless canvas_section_id.nil?
  end

end
