# frozen_string_literal: true

require 'rails_helper'

class FakeS3Reader
  attr_accessor :uploaded

  def initialize
    @uploaded = {}
  end

  def write_to_path!(filepath:)
    filepath
  end

  def upload_to_s3!(file_path_local:, file_path_for_s3:)
    uploaded[file_path_local] = file_path_for_s3
  end
end

RSpec.describe Converter do
  let(:uid) { 'uid' }
  let(:file_name) { 'file-name' }
  let(:file_ext) { 'doc' }
  let(:key) { 'key' }

  let(:subject) do
    Converter.new(
      uid: uid,
      file_name: file_name,
      file_ext: file_ext,
      key: key
    )
  end

  describe 'convert!' do
    it 'works' do
      reader = FakeS3Reader.new

      expect(S3Reader).to(
        receive(:new)
          .with(key: key, bucket: ENV['AWS_ATTACHMENTS_BUCKET'])
          .and_return(reader)
      )

      expect(File).to(receive(:open).and_return(nil).exactly(5).times)
      expect(Kristin).to(
        receive(:convert)
          .with(
            './cargo-tmp/uid/uid.pdf',
            './cargo-tmp/uid/uid.html',
            zoom: 1.25
          ).and_return(nil)
      )

      soffice = '/Applications/LibreOffice.app/Contents/MacOS/soffice'
      expect(Libreconv).to(
        receive(:convert)
        .with('./cargo-tmp/uid/uid.doc', './cargo-tmp/uid/uid.pdf', soffice)
          .and_return(nil)
      )

      subject.convert!

      expect(reader.uploaded).to(
        eq(
          {
            './cargo-tmp/uid/uid.html': '/enlist-converted-resumes/uid/uid.html',
            './cargo-tmp/uid/uid.pdf': '/enlist-converted-resumes/uid/uid.pdf'
          }.stringify_keys
        )
      )
    end
  end
end
