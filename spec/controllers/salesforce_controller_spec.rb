require 'rails_helper'

RSpec.describe SalesforceController, type: :controller do

  describe "GET #sync_to_lms" do
    xit "returns http success" do
      get :sync_to_lms
      expect(response).to have_http_status(:success)
    end
  end

end
