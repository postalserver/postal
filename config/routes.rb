# frozen_string_literal: true

Rails.application.routes.draw do
  # Legacy API Routes
  match "/api/v1/send/message" => "legacy_api/send#message", via: [:get, :post, :patch, :put]
  match "/api/v1/send/raw" => "legacy_api/send#raw", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/message" => "legacy_api/messages#message", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/deliveries" => "legacy_api/messages#deliveries", via: [:get, :post, :patch, :put]

  # Management API v2
  scope "/api/v2/management", module: "management_api/v2" do
    # System endpoints
    get "system/health" => "system#health"
    get "system/status" => "system#status"
    get "system/stats" => "system#stats"
    get "system/api_keys" => "system#api_keys_index"
    post "system/api_keys" => "system#api_keys_create"
    delete "system/api_keys/:uuid" => "system#api_keys_destroy"

    # Users (super admin only)
    resources :users, param: :uuid

    # Organizations
    resources :organizations, param: :permalink do
      member do
        post :suspend
        post :unsuspend
      end

      # Servers within organization
      resources :servers, only: [:index, :create], param: :uuid, controller: "servers"
    end

    # Servers (global access)
    resources :servers, only: [:index, :show, :update, :destroy], param: :uuid do
      member do
        post :suspend
        post :unsuspend
        get :stats
      end

      # Domains
      resources :domains, only: [:index, :show, :create, :destroy], param: :uuid do
        member do
          post :verify
          post :check_dns
        end
      end

      # Credentials
      resources :credentials, only: [:index, :show, :create, :update, :destroy], param: :uuid

      # Routes
      resources :routes, only: [:index, :show, :create, :update, :destroy], param: :uuid

      # Webhooks
      resources :webhooks, only: [:index, :show, :create, :update, :destroy], param: :uuid do
        post :test, on: :member
      end

      # Messages
      resources :messages, only: [:index, :show], param: :id do
        member do
          get :deliveries
          post :retry
          post :cancel_hold
        end
      end

      # Queue
      get :queue => "messages#queue"
    end
  end

  scope "org/:org_permalink", as: "organization" do
    resources :domains, only: [:index, :new, :create, :destroy] do
      match :verify, on: :member, via: [:get, :post]
      get :setup, on: :member
      post :check, on: :member
    end
    resources :servers, except: [:index] do
      resources :domains, only: [:index, :new, :create, :destroy] do
        match :verify, on: :member, via: [:get, :post]
        get :setup, on: :member
        post :check, on: :member
      end
      resources :track_domains do
        post :toggle_ssl, on: :member
        post :check, on: :member
      end
      resources :credentials
      resources :routes
      resources :http_endpoints
      resources :smtp_endpoints
      resources :address_endpoints
      resources :ip_pool_rules
      resources :messages do
        get :incoming, on: :collection
        get :outgoing, on: :collection
        get :held, on: :collection
        get :activity, on: :member
        get :plain, on: :member
        get :html, on: :member
        get :html_raw, on: :member
        get :attachments, on: :member
        get :headers, on: :member
        get :attachment, on: :member
        get :download, on: :member
        get :spam_checks, on: :member
        post :retry, on: :member
        post :cancel_hold, on: :member
        get :suppressions, on: :collection
        delete :remove_from_queue, on: :member
        get :deliveries, on: :member
      end
      resources :webhooks do
        get :history, on: :collection
        get "history/:uuid", on: :collection, action: "history_request", as: "history_request"
      end
      get :limits, on: :member
      get :retention, on: :member
      get :queue, on: :member
      get :spam, on: :member
      get :delete, on: :member
      get "help/outgoing" => "help#outgoing"
      get "help/incoming" => "help#incoming"
      get :advanced, on: :member
      post :suspend, on: :member
      post :unsuspend, on: :member
    end

    resources :ip_pool_rules
    resources :ip_pools, controller: "organization_ip_pools" do
      put :assignments, on: :collection
    end
    root "servers#index"
    get "settings" => "organizations#edit"
    patch "settings" => "organizations#update"
    get "delete" => "organizations#delete"
    delete "delete" => "organizations#destroy"
  end

  resources :organizations, except: [:index]
  resources :users
  resources :ip_pools do
    resources :ip_addresses
  end

  get "settings" => "user#edit"
  patch "settings" => "user#update"
  post "persist" => "sessions#persist"

  get "login" => "sessions#new"
  post "login" => "sessions#create"
  delete "logout" => "sessions#destroy"
  match "login/reset" => "sessions#begin_password_reset", :via => [:get, :post]
  match "login/reset/:token" => "sessions#finish_password_reset", :via => [:get, :post]

  if Postal::Config.oidc.enabled?
    get "auth/oidc/callback", to: "sessions#create_from_oidc"
  end

  get ".well-known/jwks.json" => "well_known#jwks"

  get "ip" => "sessions#ip"

  root "organizations#index"
end
