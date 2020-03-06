require 'rest-client'

class CanvasAPI
  attr_reader :canvas_url

  # Custom HTML to prepend to each body.
  PrependHTML = %q(
    <!-- BRAVEN_NEW_HTML -->
    <div class="bz-module">
  )

  AppendHTML = %q(
    </div>
  )

  def initialize(canvas_url, canvas_token)
    @canvas_url = canvas_url
    @api_url = "#{@canvas_url}/api/v1"
    @global_headers = {
      'Authorization' => "Bearer #{canvas_token}",
    }
  end

  def update_course_page(course_id, wiki_page_id, wiki_page_body)
    body = {
      'wiki_page[body]' => PrependHTML + wiki_page_body + AppendHTML,
    }

    put("/courses/#{course_id}/pages/#{wiki_page_id}", body)
  end

  def get(path, params={}, headers={})
    RestClient.get("#{@api_url}#{path}", {params: params}.merge(@global_headers.merge(headers)))
  end

  def post(path, body, headers={})
    RestClient.post("#{@api_url}#{path}", body, @global_headers.merge(headers))
  end

  def put(path, body, headers={})
    RestClient.put("#{@api_url}#{path}", body, @global_headers.merge(headers))
  end
end
