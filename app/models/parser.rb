require 'uri'
require 'net/http'
require 'net/https'
require 'base64'
require 'json'

class Parser
  class InvalidURL < StandardError; end
  class InvalidFile < StandardError; end

  ACCOUNT_ID = '57918929'.freeze
  SERVICE_KEY = 'kAYOxhXZHxD002Z5JZ38dAP9q2Iaqe3cbn4K3Wx7'.freeze

  def initialize(file_name:, key:, uid:)
    @uid = uid || SecureRandom.uuid
    @file_name = file_name
    @key = key
    @headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'Sovren-AccountId' => ACCOUNT_ID,
      'Sovren-ServiceKey' =>  SERVICE_KEY
    }
  end

  def parse!
    download_s3_file
    raise InvalidFile if file_is_empty?
    #revision_date = File.mtime(@filepath).to_s[0,10]
    # Encode the bytes to base64
    data = {
      "DocumentAsBase64String" => Base64.encode64(File.read(@filepath))
       #other options here (see http://documentation.sovren.com/API/Rest/Parsing)
    }.to_json
    uri = URI.parse("https://rest.resumeparsing.com/v9/parser/resume")
    https = Net::HTTP.new(uri.host,uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, initheader = @headers)
    req.body = data
    res = https.request(req)
    # Parse the response body into an object
    respObj = JSON.parse(res.body)
    # Parse the ParsedDocument string into an object (for response properties and types, see http://documentation.sovren.com/API/Rest/Parsing)
    parsedDoc = JSON.parse(respObj["Value"]["ParsedDocument"])

    {
      json: {
        contact: parsedDoc["Resume"]["StructuredXMLResume"]["ContactInfo"],
        employment:  parsedDoc["Resume"]["StructuredXMLResume"]["EmploymentHistory"],
        education:  parsedDoc["Resume"]["StructuredXMLResume"]["EducationHistory"]
      }, code: :ok
    }
  end

  def download_s3_file
    raise InvalidFile if @file_name.nil?
    @filepath = Rails.root.join(file_path)

    S3Reader
      .new(key: @key, bucket: bucket)
      .write_to_path!(filepath: @filepath)
  end

  private

  def file_is_empty?
    File.zero?(@filepath)
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
    "#{@uid}#{file_ext}"
  end

  def file_path
    "./#{dir}/#{file_name}"
  end

  def file_ext
    File.extname(@file_name)
  end

  def bucket
    ENV['AWS_ATTACHMENTS_BUCKET']
  end
end

