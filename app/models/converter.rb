class Converter
  class InvalidFileType < StandardError; end

  require 'fileutils'
  require 'libreconv'
  require 'kristin'

  def allowed_filetypes
    %w(application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document)
  end

  def initialize(uid:, file_name:, file_ext:, key:)
    @uid = uid || SecureRandom.uuid
    @file_name = file_name
    @file_ext = file_ext
    @key = key
  end

  def convert!
    download_from_s3
    convert_to_pdf unless is_pdf_file?
    convert_to_html
    upload_to_s3

    {
      file_path_to_html: file_path_for_s3_html,
      file_path_to_pdf: file_path_for_s3_pdf
    }
  end

  def reader
    S3Reader.new(key: @key, bucket: bucket)
  end

  def download_from_s3
    reader.write_to_path!(filepath: file_path)
  end

  def convert_to_pdf
    raise InvalidFileType unless allowed_filetypes.include? file_type

    if Rails.env.production?
      Libreconv.convert file_path, file_path_to_pdf

    else
      soffice = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
      Libreconv.convert file_path, file_path_to_pdf, soffice
    end
  end

  def convert_to_html
    Kristin.convert file_path_to_pdf, file_path_to_html
  end

  def upload_to_s3
    reader.upload_to_s3!(file_path_local: file_path_to_html, file_path_for_s3: file_path_for_s3_html)
    reader.upload_to_s3!(file_path_local: file_path_to_pdf, file_path_for_s3: file_path_for_s3_pdf)
  end

  private
    def create_directory(dir)
      FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
    end

    def dir
      upper = "cargo-tmp/#{@uid}"
      inner = "cargo-tmp/#{@uid}/#{@uid}"

      create_directory(upper)
      create_directory(inner)

      upper
    end

    def file_name
      "#{@uid}.#{@file_ext}"
    end

    def file_path
      "./#{dir}/#{file_name}"
    end

    def file_path_to_pdf
      return file_path if is_pdf_file?
      "./#{dir}/#{@uid}.pdf"
    end

    def file_path_to_html
      "./#{dir}/#{@uid}.html"
    end

    def file_path_for_s3_html
      "/enlist-parsed-resumes/#{@uid}/#{@uid}.html"
    end

    def file_path_for_s3_pdf
      "/enlist-parsed-resumes/#{@uid}/#{@uid}.pdf"
    end

    def file_type
      IO.popen(["file", "--brief", "--mime-type", file_path], in: :close, err: :close).read.chomp
    end

    def is_pdf_file?
      file_type == "application/pdf"
    end

    def bucket
      ENV['AWS_ATTACHMENTS_BUCKET']
    end
end
