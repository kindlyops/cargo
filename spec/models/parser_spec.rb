# frozen_string_literal: true

require 'rails_helper'
require 'sovren_client'

class FakeSovren
  def parse(file)
    OpenStruct.new(
      contact_information: {
        first_name: 'Test',
        last_name: 'Application',
        email: 'test@example.org'
      }
    )
  end
end

RSpec.describe Parser do

  let(:filepath) { Rails.root.join('spec', 'support', 'resume.pdf') }
  let(:subject) do
    Parser.new(
      file_name: 'file-name.pdf',
      key: 'key',
      uid: 'uid'
    )
  end

  let(:subject_s3) do
    S3Reader.new(
      key: 'key',
      bucket: 'bucket'
    )
  end

  describe 'parse!' do
    it 'has a client' do
      expect(subject.client).to be_kind_of SovrenClient
    end

    it 'works' do
      expect(SovrenClient).to(receive(:new).and_return(SovrenClient.new))
      expect(Aws::S3::Client).to receive(:new).and_return(FakeS3Client.new)
      expect(Aws::S3::Resource).to receive(:new).and_return(FakeS3Resource.new)

      fake_file = FakeFile.new

      expect(File).to(
        receive(:open).with(filepath, 'wb') { |&block| block.call(fake_file) }
      )

      expect(File).to receive(:read).and_return(nil)
      expect(File).to receive(:zero?).with(filepath).and_return(false)

      subject_s3.write_to_path!(filepath: filepath)

      expect(subject.parse!).to(
        eq({
          json: {
            contact: {
              first_name: 'Test',
              last_name: 'Application',
              email: 'test@example.org'
            },
            employment: nil,
            education: nil
          }, code: :ok
        })
      )
    end
  end
end
