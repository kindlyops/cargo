Rails.application.routes.draw do
  root 'parser#index'
  resources :parser, only: [:create]
end
