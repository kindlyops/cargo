class ApplicationController < ActionController::API
  rescue_from StandardError do |err|
    backtrace = if Rails.env.development?
                  err.backtrace
                else
                  nil
                end

    render json: {
      error: "#{err.class.name}: #{err.message}",
      backtrace:  backtrace
    }
  end
end
