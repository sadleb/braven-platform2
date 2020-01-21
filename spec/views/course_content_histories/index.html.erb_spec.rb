require 'rails_helper'

RSpec.describe "course_content_histories/index", type: :view do
  before(:each) do
    assign(:course_contents, [
      CourseContent.create!(
        :title => "Title",
        :body => "MyText"
      )
    ])
    assign(:course_content_histories, [
      CourseContentHistory.create!(
        :course_content => CourseContent.first,
        :title => "Title",
        :body => "MyText"
      ),
      CourseContentHistory.create!(
        :course_content => CourseContent.first,
        :title => "Title",
        :body => "MyText"
      )
    ])
  end

  it "renders a list of course_content_histories" do
    render
    assert_select "tr>td", :text => CourseContent.first.id.to_s, :count => 2
    assert_select "tr>td", :text => "Title".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
  end
end
