class Parser
  class InvalidURL < StandardError; end
  class InvalidFile < StandardError; end

  ACCOUNT_ID = '57918929'.freeze
  SERVICE_KEY = 'kAYOxhXZHxD002Z5JZ38dAP9q2Iaqe3cbn4K3Wx7'.freeze

  def initialize(file_name:, key:, uid:)
    @uid = uid || SecureRandom.uuid
    @file_name = file_name
    @key = key
  end

  def client
    Sovren::Client.new(
      endpoint: 'http://services.resumeparsing.com/ParsingService.asmx?wsdl',
      account_id: ACCOUNT_ID,
      service_key: SERVICE_KEY
    )
  end

  def parse!
    download_s3_file
    raise InvalidFile if file_is_empty?

    parsed = client.parse(File.read(@filepath))

    {
      json: {
        contact: parsed.contact_information,
        employment: parsed.employment_history,
        education: parsed.education_history
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
