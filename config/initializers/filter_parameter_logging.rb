require 'filter_logging'

# Used for filtering out the parameters that you don't want shown in the logs,
# such as passwords or credit card numbers.
if FilterLogging.is_enabled? 

  #Rails.application.config.filter_parameters += [
  #  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn
  #]

  Rails.application.config.filter_parameters << FilterLogging.filter_parameters
end
