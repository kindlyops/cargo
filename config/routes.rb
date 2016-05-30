Rails.application.routes.draw do
  root 'converter#index'
  resources :converter, only: [:create]
end
