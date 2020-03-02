require 'rails_helper'

RSpec.describe "course_content_histories/index", type: :view do
  let(:course_content) { create(:course_content) }

  before(:each) do
    assign(:course_content, course_content)
    assign(:course_content_histories, [
      CourseContentHistory.create!(
        :course_content_id => course_content.id,
        :title => "Title",
        :body => "MyText"
      ),
      CourseContentHistory.create!(
        :course_content_id => course_content.id,
        :title => "Title",
        :body => "MyText"
      )
    ])
  end

  it "renders a list of course_content_histories" do
    render
    assert_select "tr>td", :count => 8
    assert_select "tr>td", :text => "Title".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
  end
end
