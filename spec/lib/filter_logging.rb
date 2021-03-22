require 'rails_helper'
require 'filter_logging'

# TODO: ideally, I'd mock out Rails.logger and look at the messages it receives
# when posting to controller endpoints.
RSpec.describe FilterLogging do

  describe '.filter_parameters' do
    it 'is a NOOP when the value is nil' do
      param_name = 'state'
      value = nil
      expect{ FilterLogging.filter_parameters.call(param_name, value) }.not_to raise_error
      expect(value).to eq(nil)
    end

    it 'does not filter random parameter' do
      param_name = 'this_is_random'
      value = 'abcd'
      FilterLogging.filter_parameters.call(param_name, value)
      expect(value).to eq('abcd')
    end

    # Example endpoint that would send this (one of many):
    # https://platformweb/course_project_versions/42/project_submissions/162/edit?state=fake-value
    it 'filters the "state" parameter' do
      param_name = 'state'
      value = 'fake-value'
      FilterLogging.filter_parameters.call(param_name, value)
      expect(value).to eq(FilterLogging::FILTERED)
    end

    # Sent by the course_resources_controller and rise360_module_versions_controller.
    #
    # Also, hit by the lti_rise360_proxy at an endpoint like this:
    # https://platformweb/rise360_proxy/lessons/sxjdabcdefg/index.html?
    #   actor=%7B%22name%22%3A%22RISE360_USERNAME_REPLACE%22%2C%20%22mbox%22%3A%5B%22mailto%3ARISE360_PASSWORD_REPLACE%22%5D%7D&
    #   auth=LtiState%20fake-value&endpoint=https%3A%2F%2Fplatformweb%2Fdata%2FxAPI
    it 'filters the "auth" parameter' do
      param_name = 'auth'
      value = 'LtiState%20fake-value'
      FilterLogging.filter_parameters.call(param_name, value)
      expect(value).to eq(FilterLogging::FILTERED)
    end

    # Sent to the users/passwords and users/registrations controllers.
    it 'filters the "password" parameter' do
      param_name = 'password'
      value = 'Cats4Lyfe'
      FilterLogging.filter_parameters.call(param_name, value)
      expect(value).to eq(FilterLogging::FILTERED)
    end

    # Sent to the users/passwords and users/registrations controllers.
    it 'filters the "password_confirmation" parameter' do
      param_name = 'password_confirmation'
      value = 'Cats4Lyfe'
      FilterLogging.filter_parameters.call(param_name, value)
      expect(value).to eq(FilterLogging::FILTERED)
    end

    # Sent to the users/passwords controller.
    it 'filters the "reset_password_token" parameter' do
      param_name = 'reset_password_token'
      value = 'fake-reset-pass-token'
      FilterLogging.filter_parameters.call(param_name, value)
      expect(value).to eq(FilterLogging::FILTERED)
    end

    # Sent to the users/confirmations controller.
    it 'filters the "confirmation_token" parameter' do
      param_name = 'confirmation_token'
      value = 'fake-confirmation-token'
      FilterLogging.filter_parameters.call(param_name, value)
      expect(value).to eq(FilterLogging::FILTERED)
    end

    # Sent to the CAS and application controller for the CAS login stuff
    it 'filters the "ticket" parameter' do
      param_name = 'ticket'
      value = 'fake-ticket'
      FilterLogging.filter_parameters.call(param_name, value)
      expect(value).to eq(FilterLogging::FILTERED)
    end

    # HoneycombJsController sends this from Boomerang JS:
    it 'filters the "u" parameter' do
      state_value = 'fake-value'
      param_name = 'u'
      value = "https://platformweb/rise360_module_versions/18?state=#{state_value}"
      FilterLogging.filter_parameters.call(param_name, value)
      expect(value).to eq("https://platformweb/rise360_module_versions/18?state=#{FilterLogging::FILTERED}")
    end

    # HoneycombJsController sends this from Boomerang JS:
    it 'filters the "pgu" parameter' do
      state_value = 'fake-value'
      param_name = 'pgu'
      value = "https://platformweb/rise360_module_versions/18?state=#{state_value}"
      FilterLogging.filter_parameters.call(param_name, value)
      expect(value).to eq("https://platformweb/rise360_module_versions/18?state=#{FilterLogging::FILTERED}")
    end

    # HoneycombJsController sends this from Boomerang JS:
    it 'filters the "restiming" parameter' do
      state_value = 'fake-value'
      param_name = 'restiming'
      # For more info about what is inside this payload:
      # https://developer.akamai.com/tools/boomerang/docs/BOOMR.plugins.ResourceTiming.html
      get_value = -> (state, auth) { "{\"https://\":{\"platformweb\":{\"/\":{\"rise360_\":{\"module_versions/18?state=#{state}\":\"6,2it,2is,52,50,50,50,50,50,50,2*127w,1ny\",\"proxy/lessons/sxj0v0dsxa8qykfv36n1citzh6jz/\":{\"index.html?actor=%7B%22name%22%3A%22RISE360_USERNAME_REPLACE%22%2C%20%22mbox%22%3A%5B%22mailto%3ARISE360_PASSWORD_REPLACE%22%5D%7D&auth=#{auth}&endpoint=https%3A%2F%2Fplatformweb%2Fdata%2FxAPI\":\"*0ce,ui|a2oy,5l,58,8*1yfo,aa\",\"lib/\":{\"l\":{\"zwcompress.js\":\"32uh,42,41,5*16od,8x*20\",\"ms.js\":\"32ui,9b,9b,5*1916,99*20\"},\"icomoon.css\":\"22ug,5x,5w,3*15fy,97*44\",\"main.bundle.css\":\"22uh,6w,5r,4*17mwl,ku*44\",\"player-0.0.11.min.js\":\"32uh,6t,6r,5*1bap,9i*20\",\"tincan.js\":\"32ui,8r,80,4*11h6u,bc*20\"},\"tc-config.js\":\"32uh,65,64,5*1eh,8o*20\"}},\"__rack/\":{\"swfobject.js\":\"32jt,r,q,9*17vw,2k*20\",\"web_socket.js\":\"32jt,u,s,b*19uq,2k*20\"},\"packs/\":{\"boomerang-3e443c96346e90676812.js\":\"32ju,2u,2b,b*128d3,9v,74lm*20\",\"rise360_module_versions-3e443c96346e90676812.js\":\"32ju,30,2a,b*12g33,a5,7t6t*20\"},\"assets/\":{\"r\":{\"ise360_module_versions.self-cb98db08647928f567206688af870fe93f60c0d66ccdfcb014fa07bdc1b5cce4.css?body=1\":\"22ju,1o,1n,b*13z,h3*44\",\"ate_this_module.self-5cf372acc2495916aa3ce155e34848c75856de690e6a8af8fc6fbf523697631e.css?body=1\":\"22ju,2v,2s,b*127p,hp*44\"},\"layouts/rise360_container.self-01691f7fb665fe488ab7623a5d85173a1e02a7aed8fa964ae7141d97197af202.css?body=1\":\"22ju,2t,2s,b*1181,hg*44\"}},\":3035/sockjs-node/info?t=16148238758\":{\"12\":\"52pp,b\",\"22\":\"52pz,c\"}},\"fonts.googleapis.com/css2?family=Roboto:ital,wght@0,100;0,300;0,400;0,500;0,700;0,900;1,100;1,300;1,400;1,500;1,700;1,900&display=swap\":\"22ju,x,x,a*1x3,r,jiy*44\"}}" }

      value = get_value.call(state_value, "LtiState%20#{state_value}")
      expected_filtered_value = get_value.call(FilterLogging::FILTERED, FilterLogging::FILTERED)

      filtered_value = FilterLogging.filter_parameters.call(param_name, value)
      expect(filtered_value).to eq(expected_filtered_value)
    end

    # Note: the linked_in_authorization_controller gets the User.linked_in_access_token by exchanging
    # a temporary OAuth "code" param and getting the actual access token back in the body. That's
    # not logged, which is why there is no parameter spec for the LinkedIn token here.
  end

  describe '.filter_sql' do
    let(:log_name) { 'User Load' }
    let(:column_name) { 'some_column' }
    let(:bind) { double(ActiveRecord::Relation::QueryAttribute, :name => column_name, :value => column_value) }
    let(:column_value) { 'column_value' }
    let(:binds) { [bind] }
    let(:type_casted_binds) { [column_value] }
    let(:type_casted_binds_lambda) { -> { type_casted_binds } }
    let(:filtered_binds) { nil }

    let(:log_name) { 'LtiLaunch Load' }
    let(:column_name) { 'state' }
    let(:column_value) { nil }
    it 'is a NOOP when the value is nil' do
      expect{ filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda) }.not_to raise_error
      expect(filtered_binds).to eq(nil)
    end

    let(:log_name) { 'FakeModel Load' }
    let(:column_name) { 'this_is_random' }
    let(:column_value) { 'abcd' }
    it 'does not filter random model/column' do
      filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
      expect(filtered_binds).to eq(nil)
      expect(bind).not_to have_received(:name)
    end

    context 'for lti_launches table' do
      let(:log_name) { 'LtiLaunch Load' }

      let(:column_name) { 'state' }
      let(:column_value) { 'fake-state' }
      it 'filters the "state" column' do
        filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
        expect(filtered_binds).to eq([FilterLogging::FILTERED])
      end

      let(:column_name) { 'id_token_payload' }
      let(:column_value) { 'fake-payload' }
      it 'filters the "id_token_payload" column' do
        filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
        expect(filtered_binds).to eq([FilterLogging::FILTERED])
      end
    end

    context 'for users table' do
      let(:log_name) { 'User Load' }

      let(:column_name) { 'encrypted_password' }
      let(:column_value) { 'fake-enc-pass' }
      it 'filters the "encrypted_password" column' do
        filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
        expect(filtered_binds).to eq([FilterLogging::FILTERED])
      end

      let(:column_name) { 'confirmation_token' }
      let(:column_value) { 'fake-take' }
      it 'filters the "confirmation_token" column' do
        filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
        expect(filtered_binds).to eq([FilterLogging::FILTERED])
      end

      let(:column_name) { 'reset_password_token' }
      let(:column_value) { 'fake-token' }
      it 'filters the "reset_password_token" column' do
        filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
        expect(filtered_binds).to eq([FilterLogging::FILTERED])
      end

      let(:column_name) { 'linked_in_access_token' }
      let(:column_value) { 'fake-token' }
      it 'filters the "linked_in_access_token" column' do
        filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
        expect(filtered_binds).to eq([FilterLogging::FILTERED])
      end
    end

    context 'for login_tickets table' do
      let(:log_name) { 'LoginTicket Update' }
      let(:column_name) { 'ticket' }
      let(:column_value) { 'fake-ticket'}

      it 'filters the "ticket" column' do
        filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
        expect(filtered_binds).to eq([FilterLogging::FILTERED])
      end
    end

    context 'for proxy_granting_tickets table' do
      let(:log_name) { 'ProxyGrantingTicket Update' }
      let(:column_name) { 'ticket' }
      let(:column_value) { 'fake-ticket'}

      it 'filters the "ticket" column' do
        filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
        expect(filtered_binds).to eq([FilterLogging::FILTERED])
      end
    end

    context 'for service_tickets table' do
      let(:log_name) { 'ServiceTicket Create' }
      let(:column_name) { 'ticket' }
      let(:column_value) { 'fake-ticket'}

      it 'filters the "ticket" column' do
        filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
        expect(filtered_binds).to eq([FilterLogging::FILTERED])
      end
    end

    context 'for ticket_granting_tickets table' do
      let(:log_name) { 'TicketGrantingTicket Create' }
      let(:column_name) { 'ticket' }
      let(:column_value) { 'fake-ticket'}

      it 'filters the "ticket" column' do
        filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
        expect(filtered_binds).to eq([FilterLogging::FILTERED])
      end
    end

    context 'for access_tokens table' do
      let(:log_name) { 'AccessToken Create' }
      let(:column_name) { 'key' }
      let(:column_value) { 'fake-token'}

      it 'filters the "key" column' do
        filtered_binds = FilterLogging.filter_sql(log_name, binds, type_casted_binds_lambda)
        expect(filtered_binds).to eq([FilterLogging::FILTERED])
      end
    end
  end # END .filter_sql

  describe '.filter_honeycomb_data' do

    context 'when Boomerang error' do
      let(:state) { 'FAKESTATEVALUE' }

      it 'filters "error_details" field' do
        get_error_details = -> (state_val) { "https://www.google-analytics.com/j/collect?v=1&_v=j88&a=659599164&t=pageview&_s=1&dl=https%3A%2F%2Fplatform.braven.org%2Flinked_in%2Fauth%3Fstate%3D#{state_val}&ul=en-us&de=UTF-8&dt=Braven%20LTI%20Extension&sd=32-bit&sr=375x667&vp=375x559&je=0&_u=AACAAUABAAAAAC~&jid=1775313237&gjid=1393104712&cid=128933538.1616124287&tid=UA-FAKETRACKINGID-2&_gid=38343245.1616124287&_r=1&gtm=2ou3a0&z=1604529632" }
        fields = { 'name' => 'js.page.load', 'js.boomerang.error_detail' => get_error_details.call(state) }
        FilterLogging.filter_honeycomb_data(fields)
        expect(fields['js.boomerang.error_detail']).to eq(get_error_details.call(FilterLogging::FILTERED))
      end
    end
  end

end

