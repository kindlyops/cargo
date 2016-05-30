Rails.application.routes.draw do
  root 'app#index'

  resources :converter, only: [:create]
  resources :parser, only: [:create]
end
