class ProjectVersion < CustomContentVersion
  belongs_to :project, foreign_key: "custom_content_id"
end
