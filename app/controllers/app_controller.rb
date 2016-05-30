class AppController < ApplicationController
  def index
    render(
      json: 'Cargo',
      status: 200
    )
  end
end
