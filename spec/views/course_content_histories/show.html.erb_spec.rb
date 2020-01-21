require 'rails_helper'

RSpec.describe "course_content_histories/show", type: :view do
  before(:each) do
    assign(:course_contents, [
      CourseContent.create!(
        :title => "Title",
        :body => "MyText"
      )
    ])
    @course_content_history = assign(:course_content_history, CourseContentHistory.create!(
      :course_content => CourseContent.first,
      :title => "Title",
      :body => "MyText"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(Regexp.new(CourseContent.first.id.to_s))
    expect(rendered).to match(/Title/)
    expect(rendered).to match(/MyText/)
  end
end
