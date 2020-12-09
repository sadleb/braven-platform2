require 'rails_helper'

RSpec.describe CustomContent, type: :model do
  let(:course) { create :course }
  # Project with version in a course
  let(:project) { create :project }
  let!(:project_version) { create :project_version, project: project }
  let!(:course_project_version) { create :course_project_version, course: course, project_version: project_version }
  # Survey with no versions, in no courses
  let(:survey) { create :survey }

  describe '#projects' do
    subject { CustomContent.projects.first }

    it { should eq(project) }
  end

  describe '#surveys' do
    subject { CustomContent.surveys.first }

    it { should eq(survey) }
  end

  shared_examples 'serializable' do
    scenario 'hash includes type' do
      expect(custom_content.serializable_hash).to include('type')
    end
  end

  shared_examples 'belongs to Courses' do
    scenario 'returns a list of courses' do
      expect(custom_content.courses.first).to eq(in_course)
    end
  end

  shared_examples 'a Versionable' do
    scenario '#versions' do
      expect(custom_content.versions.count).to eq(custom_content_version_class.count)
    end

    scenario '#last_version' do
      expect(custom_content.last_version).to eq(custom_content_version_class.last)
    end

    scenario '#new_version' do
      version = nil
      expect {
        version = custom_content.new_version(user)
      }.to change(custom_content_version_class, :count).by(0)
      expect(version).to be_a custom_content_version_class
      expect(version.title).to eq(custom_content.title)
      expect(version.body).to eq(custom_content.body)
    end

    scenario '#save_version!' do
      version = nil
      expect {
        version = custom_content.create_version!(user)
      }.to change(custom_content_version_class, :count).by(1)
      expect(version).to be_a custom_content_version_class
      expect(version.title).to eq(custom_content.title)
      expect(version.body).to eq(custom_content.body)
    end
  end

  context 'project' do
    let(:user) { create :admin_user}
    let(:custom_content) { project }
    let(:custom_content_version_class) { ProjectVersion }
    let(:in_course) { course }

    it_behaves_like 'belongs to Courses'
    it_behaves_like 'serializable'
    it_behaves_like 'a Versionable'
  end

  context 'survey' do
    let(:user) { create :admin_user}
    let(:custom_content) { survey }
    let(:custom_content_version_class) { SurveyVersion }
    let(:in_course) { nil }

    it_behaves_like 'belongs to Courses'
    it_behaves_like 'serializable'
    it_behaves_like 'a Versionable'
  end

end
