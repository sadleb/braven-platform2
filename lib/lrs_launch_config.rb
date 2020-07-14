# Helps configure xApi enabled content to be able to send xApi statements to
# a Learners Record Store (LRS). 
#
# See:
# - https://articulate.com/support/article/Implementing-Tin-Can-API-to-Support-Articulate-Content#launching-public-content
# - https://xapi.com/try-developer/
# - https://learningpool.com/how-to-launch-elearning-content-using-xapi/
class LrsLaunchConfig

  LRS_AUTH_PARAM="auth=Basic%20#{Rails.application.secrets.lrs_auth_token}".freeze

  def initialize(fullname, email, activity_id=nil, registration=nil)
    @fullname = fullname
    @email = email
    @activity_id = activity_id
    @registration = registration
  end

  def to_query
    # This is a little hacky, but I was really struggling to get it to encode the nested stuff properly. 
    actor = ERB::Util.url_encode('{"name":["'+ @fullname + '"], "mbox":["mailto:' + @email + '"]}')
    query = "endpoint=#{Rails.application.secrets.lrs_uri}&#{LRS_AUTH_PARAM}&actor=#{actor}"
    query << "&activity_id=#{ERB::Util.url_encode(@activity_id)}" if @activity_id 
    query << "&registration=#{ERB::Util.url_encode(@registration)}" if @registration
    query
  end
end


