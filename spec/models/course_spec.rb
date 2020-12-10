require 'rails_helper'

RSpec.describe Course, type: :model do

  let(:course_name) { 'Course Name' }
  let(:course) { build :course, name: course_name }
  
  describe '#valid?' do
    subject { course }

    context 'when course name is empty' do
      let(:course_name) { '' }
      it { is_expected.to_not be_valid }
    end
  end

  describe '#save' do
    context 'when course name has extra whitespace' do
      it 'strips away the whitespace in name' do
        name_with_whitespace = "  #{course.name}  "
        course.name = name_with_whitespace
        course.save!
        expect(course.name).to eq(name_with_whitespace.strip)
      end
    end
  end

  describe '#to_show' do
    subject { course.to_show }

    it { should eq({'name' => course_name}) }
  end

  context 'with associations' do
    let(:course) { create :course, name: course_name}
    # Project
    let(:project) { create :project }
    let(:project_version) { create :project_version, project: project }
    let!(:course_project_version) { create :course_project_version, course: course, project_version: project_version }
    # Module
    let(:rise360_module_version) { create :rise360_module_version }
    let!(:course_rise360_module_version) { create(
      :course_rise360_module_version,
      course: course,
      rise360_module_version: rise360_module_version,
    ) }

    describe '#custom_contents' do
      subject { course.custom_contents.first }

      it { should eq(project) }
    end

    describe '#projects' do
      subject { course.projects.first }

      it { should eq(project) }
    end

    describe '#rise360_modules' do
      subject { course.rise360_modules.first }
      it { should eq(rise360_module_version.rise360_module) }
    end
  end
end
