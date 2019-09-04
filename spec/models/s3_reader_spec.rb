# frozen_string_literal: true

require 'rails_helper'

class FakeObject
  def initialize(key:)
    @key = key
  end

  def exists?
    true
  end

  def upload_file(file_path, acl:)
    [file_path, acl]
  end
end

class FakeS3Bucket
  def initialize(bucket:)
    @bucket = bucket
  end

  def object(key)
    FakeObject.new(key: key)
  end
end

class FakeS3Resource
  def bucket(bucket)
    FakeS3Bucket.new(bucket: bucket)
  end
end

class FakeS3Client
  def get_object(object, target:)
    target.contents = object[:key]
  end
end

class FakeFile
  attr_accessor :contents
end

RSpec.describe S3Reader do
  let(:filepath) { Rails.root.join('cargo-tmp', 'uid', 'uid.pdf') }

  let(:subject) do
    S3Reader.new(
      key: 'key',
      bucket: 'bucket'
    )
  end

  it 'has a client' do
    expect(subject.client).to be_kind_of Aws::S3::Client
  end

  it 'has a resource' do
    expect(subject.resource).to be_kind_of Aws::S3::Resource
  end

  describe 'write_to_path!' do
    it 'works' do
      expect(Aws::S3::Client).to receive(:new).and_return(FakeS3Client.new)
      expect(Aws::S3::Resource).to receive(:new).and_return(FakeS3Resource.new)

      fake_file = FakeFile.new

      expect(File).to(
        receive(:open).with(filepath, 'wb') { |&block| block.call(fake_file) }
      )

      subject.write_to_path!(filepath: filepath)
      expect(fake_file.contents).to eq 'key'
    end
  end

  describe 'upload_to_s3!' do
    it 'works' do
      expect(Aws::S3::Resource).to receive(:new).and_return(FakeS3Resource.new)

      expect_any_instance_of(FakeObject).to(
        receive(:upload_file).with(filepath, acl: 'authenticated-read')
      )

      subject.upload_to_s3!(
        file_path_local: filepath, file_path_for_s3: '/uploads/tmp/uid.pdf'
      )
    end
  end
end
