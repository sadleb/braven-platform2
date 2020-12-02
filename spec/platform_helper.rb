def fill_and_submit_login(username, password)
  # Input login credentials
  fill_in "username", :with => username
  fill_in "password", :with => password
  
  # Make sure there is a login button that can be clicked
  # Capybara with Selenium can have problems with javascript
  find("#login-submit").click
end
