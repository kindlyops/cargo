class ConverterController < ApplicationController
  before_action :authenticate_request, only: :create

  rescue_from IOError, with: :io_error
  rescue_from Converter::InvalidFileType, with: :invalid_file_type
  rescue_from S3Reader::ObjectDoesNotExist, with: :object_does_not_exist
  rescue_from Aws::S3::Errors::ServiceError, with: :s3_error

  before_action :verify_params, only: :create

  def index
    head :ok
  end

  def create
    converter = Converter.new(
      uid: converter_params[:uid],
      key: converter_params[:key],
      file_name: converter_params[:file_name],
      file_ext: converter_params[:file_ext]
    )

    result = converter.convert!
    render json: result.to_json, status: 200
  end

  private
    def converter_params
      params.require(:converter)
            .permit(:uid, :file_name, :file_ext, :key)
    end

    def verify_params
      if converter_params[:file_name].blank? or
          converter_params[:file_ext].blank? or
          converter_params[:key].blank? or
          converter_params[:uid].blank?

        return render json: { message: :required_keys_missing }, status: 422
      end
    end

    def invalid_file_type
      render json: { message: "The file type you're trying to convert is not supported" }, status: 422
    end

    def object_does_not_exist
      render json: { message: "The file you're trying to convert does not exist" }, status: 422
    end

    def io_error(error)
      logger.info error
      Raven.capture_exception(error)

      message = {
        message: "Something went wrong with reading the file (IO).",
        details: error
      }

      render json: message, status: 422
    end

    def s3_error(error)
      logger.info error
      Raven.capture_exception(error)

      message = {
        message: "Something went wrong with S3",
        details: error
      }

      render json: message, status: 422
    end

    def authenticate_request
      unauthorized unless authenticated?
    end

    def authenticated?
      token.present? and token == ENV['AUTH_TOKEN']
    end

    def token
      return nil unless request.authorization.present?
      request.authorization.gsub(/\ABearer /, '')
    end

    def unauthorized
      render json: { message: "You need to be authorized to access this" }, status: 422
    end
end
