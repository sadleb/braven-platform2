json.extract! course_content, :id, :title, :body, :published_at, :content_type, :created_at, :updated_at, :course_id,
        :course_name, :secondary_id
json.url course_content_url(course_content, format: :json)
