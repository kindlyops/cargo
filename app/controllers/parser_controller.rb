class ParserController < ApplicationController
  before_action :authenticate_request

  rescue_from IOError, with: :io_error
  rescue_from Parser::InvalidFileType, with: :invalid_file_type
  rescue_from S3Reader::ObjectDoesNotExist, with: :object_does_not_exist
  rescue_from Aws::S3::Errors::ServiceError, with: :s3_error

  before_action :verify_params, only: :create

  def create
    parser = Parser.new(
      uid: parser_params[:uid],
      key: parser_params[:key],
      file_name: parser_params[:file_name],
      file_ext: parser_params[:file_ext]
    )

    result = parser.convert!
    render json: result.to_json, status: 200
  end

  private
    def parser_params
      params.require(:parser)
            .permit(:uid, :file_name, :file_ext, :key)
    end

    def verify_params
      if parser_params[:file_name].blank? or
          parser_params[:file_ext].blank? or
          parser_params[:key].blank? or
          parser_params[:uid].blank?

        return render json: { errors: :required_keys_missing }, status: 422
      end
    end

    def invalid_file_type
      render json: { errors: "The file type you're trying to convert is not supported" }, status: 422
    end

    def object_does_not_exist
      render json: { errors: "The file you're trying to convert does not exist" }, status: 422
    end

    def io_error(error)
      message = {
        message: "Something went wrong with IO",
        details: error
      }

      render json: message, status: 422
    end

    def s3_error(error)
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
      render json: { error: "You need to be authorized to access this" }, status: 422
    end
end
