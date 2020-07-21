# Helps configure xApi enabled content to be able to send xApi statements to
# a Learners Record Store (LRS).
# 
# Note: The endpoint for the LRS is set to a the LRS_PATH on this server and 
# requests are proxied through to the actual LRS using LrsXapiProxy
#
# See:
# - https://articulate.com/support/article/Implementing-Tin-Can-API-to-Support-Articulate-Content#launching-public-content
# - https://xapi.com/try-developer/
# - https://learningpool.com/how-to-launch-elearning-content-using-xapi/
module LtiLinkSelectionHelper

  def launch_query(fullname, email, activity_id=nil, registration=nil)
    # This is a little hacky, but I was really struggling to get it to encode the nested stuff properly. 
    lrs_proxy_url = URI(root_url)
    lrs_proxy_url.path = LrsXapiProxy.lrs_path
    actor = ERB::Util.url_encode('{"name":["'+ fullname + '"], "mbox":["mailto:' + email + '"]}')
    query = "endpoint=#{lrs_proxy_url}&actor=#{actor}"
    query << "&activity_id=#{ERB::Util.url_encode(activity_id)}" if activity_id 
    query << "&registration=#{ERB::Util.url_encode(registration)}" if registration
    query
  end
end


