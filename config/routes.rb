# frozen_string_literal: true

Rails.application.routes.draw do
  # Legacy API Routes
  match "/api/v1/send/message" => "legacy_api/send#message", via: [:get, :post, :patch, :put]
  match "/api/v1/send/raw" => "legacy_api/send#raw", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/message" => "legacy_api/messages#message", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/deliveries" => "legacy_api/messages#deliveries", via: [:get, :post, :patch, :put]

  # Management API Routes - Full administrative control
  # Authentication: X-Management-API-Key header
  # All endpoints return JSON with { status, time, data } format
  namespace :management_api, path: "management/api/v1" do

    # ===========================================
    # Users - Global user management
    # ===========================================
    resources :users, only: [:index, :show, :create, :update, :destroy] do
      member do
        post :reset_password
      end
    end

    # ===========================================
    # IP Pools - Global IP pool management
    # ===========================================
    resources :ip_pools, only: [:index, :show, :create, :update, :destroy] do
      resources :ip_addresses, only: [:index, :show, :create, :update, :destroy]
    end

    # ===========================================
    # Organizations - Organization management
    # ===========================================
    resources :organizations, only: [:index, :show, :create, :update, :destroy] do
      member do
        post :suspend
        post :unsuspend
      end

      # Organization users
      resources :users, controller: "organization_users", only: [:index, :show, :create, :update, :destroy] do
        member do
          post :make_owner
        end
      end

      # IP pools for organization
      get "ip_pools", to: "ip_pools#for_organization"
      post "ip_pools/assign", to: "ip_pools#assign_to_organization"

      # IP pool rules for organization
      resources :ip_pool_rules, only: [:index, :create]
    end

    # ===========================================
    # Servers - Mail server management
    # ===========================================
    resources :servers, only: [:index, :show, :create, :update, :destroy] do
      member do
        post :suspend
        post :unsuspend
      end

      # Domains
      resources :domains, only: [:index, :show, :create, :destroy] do
        member do
          post :verify
          post :check_dns
          get :dns_records
        end
      end

      # Credentials (API keys, SMTP credentials)
      resources :credentials, only: [:index, :show, :create, :update, :destroy]

      # Webhooks
      resources :webhooks, only: [:index, :show, :create, :update, :destroy]

      # Routes (mail routing)
      resources :routes, only: [:index, :show, :create, :update, :destroy]

      # Endpoints
      resources :http_endpoints, only: [:index, :show, :create, :update, :destroy]
      resources :smtp_endpoints, only: [:index, :show, :create, :update, :destroy]
      resources :address_endpoints, only: [:index, :show, :create, :update, :destroy]

      # Track domains (click/open tracking)
      resources :track_domains, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :check_dns
          post :toggle_ssl
        end
      end

      # IP pool rules for server
      resources :ip_pool_rules, only: [:index, :show, :create, :update, :destroy]

      # Messages
      resources :messages, only: [:index, :show, :destroy] do
        member do
          post :retry
          post :cancel_hold
          get :deliveries
          get :activity
          get :plain
          get :html
          get :headers
          get :raw
          get :spam_checks
        end
      end

      # Statistics
      get "statistics", to: "statistics#index"
      get "statistics/summary", to: "statistics#summary"
      get "statistics/by_status", to: "statistics#by_status"
      get "statistics/by_domain", to: "statistics#by_domain"
      get "statistics/clicks_and_opens", to: "statistics#clicks_and_opens"

      # Suppressions
      resources :suppressions, only: [:index, :create, :destroy], param: :address do
        collection do
          get :check
          post :bulk, action: :bulk_create
          delete :bulk, action: :bulk_destroy
        end
      end

      # Queue management
      get "queue", to: "queued_messages#index"
      get "queue/summary", to: "queued_messages#summary"
      get "queue/:id", to: "queued_messages#show", as: :queue_message
      delete "queue/:id", to: "queued_messages#destroy"
      post "queue/:id/retry", to: "queued_messages#retry_now"
      delete "queue/clear", to: "queued_messages#clear"
      post "queue/retry_all", to: "queued_messages#retry_all"
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
