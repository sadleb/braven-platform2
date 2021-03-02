# frozen_string_literal: true

# Represents the grade for a Rise360Module.
#
# Note that this doesn't actually store the grade itself. It's computed on
# the fly when needed b/c there are a lot of variables that go into it which
# can change such as an extension being granted or a manual override. The
# main purpose of this model is to map the user to the Canvas assignment so
# we can have an endpoint that will show information about their grade.
# It's analagous to something like a ProjectSubmission but there is no
# "submit" button, hence the "grade" naming
class Rise360ModuleGrade < ApplicationRecord
  belongs_to :user
  belongs_to :course_rise360_module_version
  validates :user, :course_rise360_module_version, presence: true
end
