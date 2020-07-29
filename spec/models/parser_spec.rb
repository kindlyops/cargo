# frozen_string_literal: true

require 'rails_helper'

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
  let(:filepath) { Rails.root.join('cargo-tmp', 'uid', 'uid.pdf') }

  let(:subject) do
    Parser.new(
      file_name: 'file-name.pdf',
      key: 'key',
      uid: 'uid'
    )
  end

  describe 'parse!' do
    it 'works' do
      expect(Sovren::Client).to(receive(:new).and_return(FakeSovren.new))

      fake_s3_reader = double
      expect(fake_s3_reader).to(
        receive(:write_to_path!).with(filepath: filepath)
      )

      expect(S3Reader).to(
        receive(:new).with(key: 'key', bucket: ENV['AWS_ATTACHMENTS_BUCKET'])
        .and_return(fake_s3_reader)
      )

      expect(File).to receive(:read).and_return(nil)
      expect(File).to receive(:zero?).with(filepath).and_return(false)

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
