require 'rails_helper'

RSpec.describe "course_content_histories/new", type: :view do
  before(:each) do
    assign(:course_content_history, CourseContentHistory.new(
      :course_content => nil,
      :title => "MyString",
      :body => "MyText"
    ))
  end

  it "renders new course_content_history form" do
    render

    assert_select "form[action=?][method=?]", course_content_histories_path, "post" do

      assert_select "input[name=?]", "course_content_history[course_content_id]"

      assert_select "input[name=?]", "course_content_history[title]"

      assert_select "textarea[name=?]", "course_content_history[body]"
    end
  end
end
