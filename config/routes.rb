Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Sleep records routes
  get "users/:user_id/sleep_records", to: "sleep_records#index"
  get "users/:user_id/friends_sleep_records", to: "sleep_records#friends_sleep_records"

  # Clock operations routes
  post "users/:user_id/clock_in", to: "clock#clock_in"
  patch "users/:user_id/clock_out", to: "clock#clock_out"

  # Defines the root path route ("/")
  # root "posts#index"
end
