json.partial! "custom_contents/custom_content", custom_content: @custom_content
json.canvas_url "#{CanvasAPI.client.canvas_url}courses/#{@custom_content.course_id}/assignment/#{@custom_content.secondary_id}"
