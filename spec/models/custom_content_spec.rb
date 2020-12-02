require 'rails_helper'

RSpec.describe CustomContent, type: :model do
  let(:course) { create :course }
  # Project with version in a course
  let(:project) { create :project }
  let!(:project_version) { create :project_version, project: project }
  let!(:course_project_version) { create :course_project_version, course: course, project_version: project_version }
  # Survey with no versions, in no courses
  let(:survey) { create :survey }

  describe '#last_version' do
    subject { project.last_version }

    it { should eq(project_version) }
  end

  describe '#last_version' do
    subject { survey.last_version }

    it { should eq(nil) }
  end

  describe '#projects' do
    subject { CustomContent.projects.first }

    it { should eq(project) }
  end

  describe '#surveys' do
    subject { CustomContent.surveys.first }

    it { should eq(survey) }
  end

  describe '#courses' do
    subject { project.courses.first }

    it { should eq(course) }
  end

  describe '#courses' do
    subject { project.courses.first }

    it { should eq(course) }
  end

  describe '#serializable_hash' do
    subject { project.serializable_hash }

    it { should include("type")  }
  end

end
