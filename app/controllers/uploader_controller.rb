class UploaderController < ApplicationController
  rescue_from Uploader::InvalidFileType, with: :invalid_file_type

  def create
    uploader = Uploader.new(
      file: params[:file],
      is_resume: params[:is_resume]
    )

    key = uploader.upload!

    render(
      json: {
        key: key
      },
      status: 200
    )
  end

  private

    def invalid_file_type
      render json: { errors: "The file type you're trying to upload is not supported" }, status: 422
    end
end
