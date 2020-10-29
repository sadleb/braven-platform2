require 'rails_helper'

RSpec.describe CustomContentVersion, type: :model do
  let(:project_version) { create(:project_version) }
  let(:survey_version) { create(:survey_version) }

  it { should belong_to :custom_content }

  describe '#project_versions' do
    subject { CustomContentVersion.project_versions.first }

    it { should eq(project_version) }
  end

  describe '#surveys' do
    subject { CustomContentVersion.survey_versions.first }

    it { should eq(survey_version) }
  end

end
