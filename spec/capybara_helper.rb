RSpec.configure do |config|
  config.include Capybara::DSL
end

chrome_shim = ENV.fetch('GOOGLE_CHROME_SHIM', nil)
if chrome_shim
  Selenium::WebDriver::Chrome.path = chrome_shim

  chrome_opts = chrome_shim ? { "chromeOptions" => { "binary" => chrome_shim, "remote-debugging-port" => "9222", "headless" => true } } : {}
  puts chrome_opts

  Capybara.register_driver :chrome do |app|
    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      desired_capabilities: Selenium::WebDriver::Remote::Capabilities.chrome(chrome_opts)
    )
  end

  Capybara.javascript_driver = :chrome
else
  Capybara.javascript_driver = :selenium_chrome_headless
end


