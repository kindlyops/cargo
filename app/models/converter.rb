# frozen_string_literal: true

# Converter takes a file given a key, downloads it from S3, converts it to PDF,
# then uploads it back to S3.
class Converter
  class InvalidFileType < StandardError; end

  require 'fileutils'
  require 'libreconv'
  require 'kristin'
  require 'mimemagic'
  require 'mimemagic/overlay'

  def allowed_filetypes
    doc_file_types + text_file_types
  end

  def doc_file_types
    %w[application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document]
  end

  def text_file_types
    %w[text/plain application/rtf application/x-rtf text/richtext]
  end

  def initialize(uid:, file_name:, file_ext:, key:)
    @uid = uid || SecureRandom.uuid
    @file_name = file_name
    @file_ext = file_ext
    @key = key
  end

  def convert!
    download_from_s3 unless already_exists?
    convert_to_pdf unless pdf_file?
    convert_to_html
    upload_to_s3

    {
      file_path_to_html: file_path_for_s3_html,
      file_path_to_pdf: file_path_for_s3_pdf
    }
  end

  def reader
    @reader ||= S3Reader.new(key: @key, bucket: bucket)
  end

  def download_from_s3
    reader.write_to_path!(filepath: file_path)
  end

  def convert_to_pdf
    raise InvalidFileType unless valid_type?

    if Rails.env.production? || Rails.env.staging?
      Libreconv.convert(file_path, file_path_to_pdf, '/usr/bin/soffice')
    else
      soffice = '/Applications/LibreOffice.app/Contents/MacOS/soffice'
      Libreconv.convert(file_path, file_path_to_pdf, soffice)
    end
  end

  def convert_to_html
    Kristin.convert(file_path_to_pdf, file_path_to_html, zoom: 1.25)
  end

  def upload_to_s3
    reader.upload_to_s3!(
      file_path_local: file_path_to_html,
      file_path_for_s3: file_path_for_s3_html
    )

    reader.upload_to_s3!(
      file_path_local: file_path_to_pdf,
      file_path_for_s3: file_path_for_s3_pdf
    )
  end

  private

  def valid_type?
    allowed_filetypes.include?(file_type) || docx?
  end

  def docx?
    file_type === 'application/zip' && File.extname(file_path) == '.docx'
  end

  def create_directory(dir)
    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
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
    return file_path if pdf_file?
    "./#{dir}/#{@uid}.pdf"
  end

  def file_path_to_html
    "./#{dir}/#{@uid}.html"
  end

  def file_path_for_s3_html
    "/enlist-converted-resumes/#{@uid}/#{@uid}.html"
  end

  def file_path_for_s3_pdf
    "/enlist-converted-resumes/#{@uid}/#{@uid}.pdf"
  end

  def file_type
    file = File.open(file_path)
    mime = MimeMagic.by_magic(file) || MimeMagic.by_path(file_path)
    mime.type
  end

  def pdf_file?
    file_type == 'application/pdf'
  end

  def bucket
    ENV['AWS_ATTACHMENTS_BUCKET']
  end

  def already_exists?
    File.exists?(file_path)
  end
end
