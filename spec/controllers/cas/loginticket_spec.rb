require "rails_helper"
require "capybara_helper"
require "json"

RSpec.describe CasController, type: :routing do
  describe "RubyCAS routing" do
    describe "/cas/loginTicket" do
      context "attempts a GET request" do
        before(:each) do
          visit "/cas/loginTicket"
        end
        it "returns error" do 
          expect(page.body).to include("To generate a login ticket, you must make a POST request.")
  
          result = JSON.parse(page.body)
          expect(result).to include("response")
          expect(result['response']).to include("To generate a login ticket, you must make a POST request.") 
        end
      end

      context "performs a POST request" do
        before(:each) do
          page.driver.post("/cas/loginTicket")
        end
        it "dispense a login ticket" do
          expect(page.body).to include("ticket")

          result = JSON.parse(page.body)
          expect(result).to include("ticket")
          expect(result['ticket']).to include("LT-") 
        end
      end
    end
  end
end
