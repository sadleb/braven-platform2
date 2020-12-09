require 'rails_helper'

RSpec.describe Rise360ModuleVersion, type: :model do
  let(:rise360_module_version) { create(:rise360_module_version) }

  it { should belong_to :rise360_module }
  it { should belong_to :user }
  it { should validate_presence_of :name }
end
