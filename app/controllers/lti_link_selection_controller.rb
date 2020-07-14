class LtiLinkSelectionController < ApplicationController
  # Non-standard controller without normal CRUD methods. Disable the convenience module.
  def dry_crud_enabled?() false end
end
