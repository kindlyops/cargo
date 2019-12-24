Rails.application.routes.draw do
  root 'app#index'

  resources :converter, only: [:create]
  resources :parser, only: [:create]
  resources :uploader, only: [:create]
end

Jets.application.routes.draw do
  get  "app", to: "app#index"

  resources :uploader
  resources :converter
  resources :parser
end