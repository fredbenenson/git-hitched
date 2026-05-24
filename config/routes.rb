Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"

  # Site gate
  get  "gate", to: "gate#new",    as: :gate
  post "gate", to: "gate#create"

  # RSVP flow
  get  "rsvp",                to: "rsvps#new",    as: :rsvp
  post "rsvp/lookup",         to: "rsvps#lookup", as: :rsvp_lookup
  get  "rsvp/manage",         to: "rsvps#manage", as: :rsvp_manage
  get  "rsvp/:invite_id",  to: "rsvps#show",   as: :rsvp_show
  post "rsvp/:invite_id",  to: "rsvps#update",  as: :rsvp_update

  # Standalone children-preferences page (highchair + reception dinner seating)
  get   "children/:token", to: "children_preferences#show",   as: :children_preferences
  patch "children/:token", to: "children_preferences#update", as: :update_children_preferences

  # Content pages
  get "style-guide", to: "pages#style_guide"
  get "events",      to: "pages#events"
  get "travel",      to: "pages#travel"
  get "stay",        to: "pages#stay"
  get "explore",     to: "pages#explore"
  get "attire",      to: "pages#attire"
  get "faq",         to: "pages#faq"
  get "our-story",   to: "pages#our_story"
  get "gallery",     to: "pages#gallery"

  # Hotel bookings
  resources :hotel_bookings, only: [ :new, :create ] do
    member do
      get "success", to: "hotel_bookings#success", as: :success
      get "cancel",  to: "hotel_bookings#cancel",  as: :cancel
    end
  end

  # Stripe webhooks
  post "stripe/webhooks", to: "stripe_webhooks#create"

  # Legacy redirect
  get "details", to: redirect("/events")

  # Dev-only toggle for page feature flags
  post "dev/toggle_pages", to: "dev#toggle_pages", as: :dev_toggle_pages if Rails.env.development?

  # Admin
  namespace :admin do
    root to: "dashboard#index"
    get "dashboard", to: "dashboard#index"
    resources :invites do
      collection { get :search }
      member do
        patch :link
        patch :toggle_reminder
      end
      resource :rsvp, only: [ :edit, :update ], controller: "rsvps"
    end
    resources :guests
    resources :events do
      resource :seating, only: [ :show ], controller: "seating" do
        post :randomize
        post :move
        post :undo
        post :lock_all
        post :unlock_all
        post :clear
      end
    end
    get "children", to: "children#index", as: :children
    get "seating", to: "seating#index", as: :seating
    resources :seating_tables, only: [] do
      post :shuffle_seats, on: :member
    end
    resources :seat_assignments, only: [] do
      patch :toggle_lock, on: :member
    end
    resources :hotel_bookings, only: [ :index ] do
      post :refund, on: :member
    end
    get  "notes",             to: "invites#notes",            as: :notes
    get  "emails",            to: "emails#index",             as: :emails
    post "export",            to: "emails#export",            as: :export
    post "send_invitations",  to: "emails#send_invitations",  as: :send_invitations
    post "send_reminders",    to: "emails#send_reminders",    as: :send_reminders
    post "send_children_preferences", to: "emails#send_children_preferences", as: :send_children_preferences
    post "send_test_email",   to: "emails#send_test_email",   as: :send_test_email
    get  "import",  to: "imports#new",      as: :import
    post "import",  to: "imports#create"
    get  "exports/guests.xlsx",  to: "exports#guests_xlsx",  as: :guests_xlsx_export
    get  "exports/seating.xlsx", to: "exports#seating_xlsx", as: :seating_xlsx_export
  end
end
