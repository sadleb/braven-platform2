require 'rails_helper'

RSpec.describe "course_contents/show", type: :view do
  before(:each) do
    assign(:course_content, CourseContent.create!(
      :title => "Title",
      :body => "<p>MyText</p>",
      :content_type => "wiki_page"
    ))
  end

  it "renders HTML" do
    render
    expect(rendered).to match(/<p>MyText<\/p>/)
  end

  it "adds appropriate div class for module" do
    render
    expect(rendered).to match(/<div class="bz-module">/)
  end


  it "adds appropriate div class for assignment" do
    assign(:course_content, CourseContent.create!(
      :title => "Title",
      :body => "<p>MyText</p>",
      :content_type => "assignment"
    ))
    render
    expect(rendered).to match(/<div class="bz-assignment">/)
  end
end
