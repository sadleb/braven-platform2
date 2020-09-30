require 'rails_helper'

RSpec.describe "custom_content_versions/index", type: :view do
  let(:course_content) { create(:course_content) }
  let(:user) { create(:admin_user) }

  before(:each) do
    assign(:course_content, course_content)
    assign(:user, user)
    assign(:custom_content_versions, [
      CustomContentVersion.create!(
        :course_content_id => course_content.id,
        :user => user,
        :title => "Title",
        :body => "MyText"
      ),
      CustomContentVersion.create!(
        :course_content_id => course_content.id,
        :user => user,
        :title => "Title",
        :body => "MyText"
      )
    ])
  end

  it "renders a list of custom_content_versions" do
    render
    assert_select "tr>td", :count => 10
    assert_select "tr>td", :text => "Title".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
  end
end
