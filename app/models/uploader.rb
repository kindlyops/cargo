class Uploader
  class InvalidFileType < StandardError; end

  require 'fileutils'
  require 'mimemagic'
  require 'mimemagic/overlay'

  def initialize(file:, is_resume: false)
    @file = file
    @is_resume = is_resume
  end

  def upload!
    if @is_resume
      raise InvalidFileType unless docs.include?(file_type.to_s)
    else
      raise InvalidFileType unless allowed_file_types.include?(file_type.to_s)
    end

    client.upload_to_s3!(
      file_path_local: @file.path,
      file_path_for_s3: file_path_for_s3
    )

    file_path_for_s3
  end

  private

    def docs
      %w(application/msword application/pdf text/rtf text/plain application/vnd.openxmlformats-officedocument.wordprocessingml.document)
    end

    def images
      %w(image/png image/jpeg image/gif image/svg+xml)
    end

    def zip
      %w(application/zip application/x-tar)
    end

    def allowed_file_types
      docs + images + zip
    end

    def file_type
      MimeMagic.by_magic @file
    end

    def bucket
      ENV['AWS_ATTACHMENTS_BUCKET']
    end

    def key
      SecureRandom.uuid
    end

    def client
      @client ||= S3Reader.new(key: key, bucket: bucket)
    end

    def file_path_for_s3
      "/uploads/#{key}/#{@file.original_filename}"
    end
end
