# Needed to use the url_helpers outside of views and controller
Rails.application.routes.default_url_options[:host] = Rails.application.secrets.application_host

Rails.application.routes.draw do

  resources :course_resources

  resources :rise360_modules, only: [:index, :new, :create, :edit, :update, :destroy]

  resources :rise360_module_versions, only: [:show]

  resources :custom_contents do
    resources :custom_content_versions, path: 'versions', only: [:index, :show]
  end

  resources :projects, controller: "custom_contents", type: "Project" do
    resources :project_versions, path: 'versions', controller: 'custom_content_versions', type: "ProjectVersion", only: [:index, :show]
  end

  resources :surveys, controller: "custom_contents", type: "Survey" do
    resources :survey_versions, path: 'versions', controller: 'custom_content_versions', type: "SurveyVersion", only: [:index, :show]
  end

  resources :attendance_events, only: [:index, :new, :create, :destroy]

  resources :file_upload, only: [:create]

  devise_for :users, controllers: {
    registrations: 'users/registrations',
    confirmations: 'users/confirmations',
    passwords: 'users/passwords',
    cas_sessions: 'users/cas_sessions' }

  devise_scope :user do
    get 'users/password/check_email', to: "users/passwords#check_email"
    get 'users/registration', to: "users/registrations#show"
    post '/admin/users', to: 'users#create'
    get 'users/confirmation/show_resend', to: "users/confirmations#show_resend"
  end

  get 'home/welcome'

  # See this for why we nest things only 1 deep:
  # http://weblog.jamisbuck.org/2007/2/5/nesting-resources

  resources :courses do

    collection do
      get :launch, to: 'courses#launch_new'
      post :launch, to: 'courses#launch_create'
    end

    resources :course_project_versions, only: [:new] do
      post :publish, on: :collection
      put :publish_latest, on: :member
      delete :unpublish, on: :member
    end

    resources :course_survey_versions, only: [:new] do
      post :publish, on: :collection
      put :publish_latest, on: :member
      delete :unpublish, on: :member
    end

    resources :course_rise360_module_versions, only: [:new] do
      post :publish, on: :collection
      put :publish_latest, on: :member
      get :before_publish_latest, on: :member
      delete :unpublish, on: :member
      get :before_unpublish, on: :member
    end

    resources :course_attendance_events, only: [:new] do
      post :publish, on: :collection
      delete :unpublish, on: :member
    end

    resources :capstone_evaluation_submissions, only: [:new, :create]
    resources :fellow_evaluation_submissions, only: [:new, :create]

    resources :waivers, only: [] do
      collection do
        post :publish
        delete :unpublish
      end
    end

    resources :capstone_evaluations, only: [] do
      collection do
        post :publish
        delete :unpublish
      end
    end

    resources :preaccelerator_surveys, controller: 'accelerator_surveys', type: 'Pre', only: [] do
      collection do
        post :publish
        delete :unpublish
      end
    end

    resources :postaccelerator_surveys, controller: 'accelerator_surveys', type: 'Post', only: [] do
      collection do
        post :publish
        delete :unpublish
      end
    end

    resources :fellow_evaluations, only: [] do
      collection do
        post :publish
        delete :unpublish
      end
    end
  end

  resources :rise360_module_grades, only: [:show]

  resources :course_custom_content_versions, only: [:create, :update, :destroy]

  resources :course_project_versions, only: [] do
    resources :project_submissions, only: [:new, :edit, :show]
    post 'project_submissions/submit', to: 'project_submissions#submit'
  end

  resources :project_submissions, only: [] do
    resources :project_submission_answers, only: [:index, :create]
  end

  resources :course_survey_versions, only: [] do
    resources :survey_submissions, only: [:new, :create]
  end

  resources :survey_submissions, only: [:show]
  resources :capstone_evaluation_submissions, only: [:show]

  resources :attendance_event_submissions, only: [:edit, :update] do
    collection do
      get :launch
    end
  end

  resources :attendance_event_submission_answers, only: [] do
    collection do
      get :launch
    end
  end

  resources :preaccelerator_survey_submissions, controller: 'accelerator_survey_submissions', type: 'Pre', only: [:new, :create] do
    collection do
      get :launch
      get :completed
    end
  end

  resources :postaccelerator_survey_submissions, controller: 'accelerator_survey_submissions', type: 'Post', only: [:new, :create] do
    collection do
      get :launch
      get :completed
    end
  end

  resources :waiver_submissions, only: [:new, :create] do
    collection do
      get :launch
      get :completed
    end
  end

  resources :fellow_evaluation_submissions, only: [:show]

  resources :rate_this_module_submissions, only: [:edit, :update] do
    collection do
      get :launch
    end
  end

  resources :access_tokens, except: [:show]

  # Exposes the public JWK so that external services can encode payloads using it and we
  # can decode them using our private key. E.g. JWK authentication flows.
  resources :keypairs, only: :index, format: :j, path: 'public_jwk'

  root to: "home#welcome"

  resources :users do
    member do
      post 'confirm' => 'users#confirm'
      post 'register' => 'users#register'
      get 'send_new_signup_email' => 'users#show_send_signup_email'
      post 'send_new_signup_email' => 'users#send_signup_email'
    end

    resources :users_roles, only: [:new, :create, :destroy]
  end

  # Sync to Canvas
  post '/salesforce/sync_from_salesforce_program', to: 'salesforce#sync_from_salesforce_program'
  get '/salesforce/confirm_send_signup_emails', to: 'salesforce#confirm_send_signup_emails'
  get '/salesforce/sync_from_salesforce_program', to: 'salesforce#init_sync_from_salesforce_program'
  post '/salesforce/update_contacts', to: 'salesforce#update_contacts'

  # RubyCAS Routes
  resources :cas, except: [:show]
  get '/cas/login', to: 'cas#login'
  post '/cas/login', to: 'cas#loginpost'
  get '/cas/logout', to: 'cas#logout'
  get '/cas/loginTicket', to: 'cas#loginTicket'
  post '/cas/loginTicket', to: 'cas#loginTicketPost'
  get '/cas/validate', to: 'cas#validate'
  get '/cas/serviceValidate', to: 'cas#serviceValidate'
  get '/cas/proxyValidate', to: 'cas#proxyValidate'
  get '/cas/proxy', to: 'cas#proxy'

  # LinkedIn authorization routes
  get '/linked_in/login' => 'linked_in_authorization#login'
  get '/linked_in/auth' => 'linked_in_authorization#launch'
  get '/linked_in/auth_redirect' => 'linked_in_authorization#oauth_redirect'

  # LTI Extension Routes
  post '/lti/login', to: 'lti_launch#login'
  post '/lti/launch', to: 'lti_launch#launch'
  get '/lti/course_resources', to: 'course_resources#lti_show'

  # Braven Network routes
  resources :champions, only: [:new, :create] do
    collection do
      get :connect, to: 'champions#connect'
      post :request_contact, to: 'champions#request_contact'
      get :terms, to: 'champions#terms'
    end

    member do
      get :contact, to: 'champions#contact'
      delete :contact, to: 'champions#delete_contact'
      get :fellow_survey, to: 'champions#fellow_survey'
      get :champion_survey, to: 'champions#champion_survey'
      post :fellow_survey, to: 'champions#fellow_survey_save'
      post :champion_survey, to: 'champions#champion_survey_save'
      patch :fellow_survey, to: 'champions#fellow_survey_save'
      patch :champion_survey, to: 'champions#champion_survey_save'
    end
  end

  # Send xAPI messages to our mock LRS.
  match '/data/xAPI/*endpoint', to: 'lrs_xapi_mock#xAPI', via: [:get, :put]

  # There is a route similar to the commented out one below that doesn't show up here. See 'lib/lti_rise360_proxy.rb' and 'config/application.rb'
  # match '/rise360_proxy/*endpoint', to: AWS_S3

  # Honeycomb Instrumentation Routes
  post '/honeycomb_js/send_span', to: 'honeycomb_js#send_span'

  # Catch-all route for missing ones to return an unauthorized response rather than a 404
  get '*other', to: 'home#missing_route'
  post '*other', to: 'home#missing_route'
  put '*other', to: 'home#missing_route'
  patch '*other', to: 'home#missing_route'
  delete '*other', to: 'home#missing_route'
end
