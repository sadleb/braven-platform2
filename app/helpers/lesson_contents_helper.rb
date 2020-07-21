require 'lrs_xapi_proxy'

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
module LessonContentsHelper
  
  def launch_query
    lrs_proxy_url = URI(root_url)
    lrs_proxy_url.path = LrsXapiProxy.lrs_path
    {
      :endpoint => lrs_proxy_url.to_s,
      # Our LRS proxy will supply the correct values for these
      # Send empty values to get the Rise 360 Tincan code won't error out on missing keys
      :actor => '{"name":"", "mbox":["mailto:''"]}',
    }
  end
end
