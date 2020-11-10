require 'rails_helper'

RSpec.describe BaseCourse, type: :model do

  let(:course_name) { 'Course Or Template Name' }
  let(:base_course) { build :base_course, name: course_name}

  let(:course) { create :course }
  let(:project) { create :project }
  let(:project_version) { create :project_version, project: project }
  let!(:base_course_project_version) { create :course_project_version, base_course: course, project_version: project_version }

  describe '#valid?' do
    subject { base_course }

    context 'when course name is empty' do
      let(:course_name) { '' }
      it { is_expected.to_not be_valid }
    end
  end

  describe '#to_show' do
    subject { base_course.to_show }

    it { should eq({'name' => course_name}) }
  end

  describe '#custom_contents' do
    subject { course.custom_contents.first }

    it { should eq(project) }
  end

  describe '#projects' do
    subject { course.projects.first }

    it { should eq(project) }
  end
end
