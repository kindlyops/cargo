# Reads from S3
class S3Reader
  class ObjectDoesNotExist < StandardError; end

  def initialize(key:, bucket:)
    @key = key
    @bucket = bucket
  end

  def client
    Aws::S3::Client.new
  end

  def resource
    Aws::S3::Resource.new
  end

  def write_to_path!(filepath:)
    object = resource.bucket(@bucket).object(@key)
    raise ObjectDoesNotExist unless object.exists?

    File.open(filepath, 'wb') do |file|
      client.get_object(
        object_to_get,
        target: file
      )
    end
  end

  def upload_to_s3!(file_path_local:, file_path_for_s3:)
    resource
      .bucket(@bucket)
      .object(file_path_for_s3)
      .upload_file(file_path_local, acl: 'private')
  end

  private

  def object_to_get
    { bucket: @bucket, key: @key }
  end
end
