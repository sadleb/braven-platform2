require 'rails_helper'

RSpec.describe CourseRise360ModuleVersion, type: :model do
  let(:course) { create :course }
  let(:rise360_module_version) { create :rise360_module_version }
  let(:course_rise360_module_version) { create(
    :course_rise360_module_version,
    course: course,
    rise360_module_version: rise360_module_version,
  ) }

  it { should belong_to :course }
  it { should belong_to :rise360_module_version }

  it { should validate_presence_of :course }
  it { should validate_presence_of :rise360_module_version }

  describe '#canvas_url' do
    subject { course_rise360_module_version.canvas_url }
    it { should include course.canvas_course_id.to_s }
    it { should include course_rise360_module_version.canvas_assignment_id.to_s }
  end
end
