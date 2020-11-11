json.extract!(
  custom_content,
  :id,
  :title,
  :body,
  :published_at,
  :created_at,
  :updated_at,
  :type,
)
json.url custom_content_url(custom_content, format: :json)
