class Parser
  class InvalidURL < StandardError; end
  class InvalidFile < StandardError; end

  require 'rest_client'

  PROCESSING_URL = "http://processing.resumeparser.com/requestprocessing.html"
  PROCESSING_KEY = "11f94f1fde6410dbc44448808a10031c"

  def initialize(file_name:, key:, uid:)
    @uid = uid || SecureRandom.uuid
    @file_name = file_name
    @key = key
  end

  def parse!
    download_s3_file

    if file_is_empty?
      raise InvalidFile
      return
    end

    res = RestClient.post(PROCESSING_URL, {
      product_code: PROCESSING_KEY,
      document_title: @file_name,
      document: File.new(@filepath, 'rb')
    })

    json = Hash.from_xml(res.body)
    code = res.code

    {
      :json => format(json),
      :code => code
    }
  end

  def download_s3_file
    raise InvalidFile if @file_name.nil?
    @filepath = "#{Rails.root}/#{file_path}"

    S3Reader.new(key: @key, bucket: bucket)
             .write_to_path!(filepath: @filepath)
  end

  private
    def file_is_empty?
      File.zero?(@filepath)
    end

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

    def bucket
      ENV['AWS_ATTACHMENTS_BUCKET']
    end

    def format(response)
      response.extend Hashie::Extensions::DeepFind

      {
        first_name: response.deep_find("GivenName"),
        last_name: response.deep_find("FamilyName"),
        email: response.deep_find("InternetEmailAddress")
      }
    end
end
