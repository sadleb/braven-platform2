class SurveyVersion < CustomContentVersion
  belongs_to :survey, foreign_key: "custom_content_id"
end
